require 'dotenv/load'
require 'resemble'
require 'ruby/openai'
require 'rover-df'
require 'matrix'

Resemble.api_key = ENV["RESEMBLE_API_KEY"]

class Api::V1::AskController < ApplicationController
  skip_forgery_protection

  COMPLETIONS_MODEL = "text-davinci-003"

  MODEL_NAME = "curie"

  DOC_EMBEDDINGS_MODEL = "text-search-#{MODEL_NAME}-doc-001"
  QUERY_EMBEDDINGS_MODEL = "text-search-#{MODEL_NAME}-query-001"

  MAX_SECTION_LEN = 500
  SEPARATOR = "\n* "
  SEPARATOR_LEN = 3

  COMPLETIONS_API_PARAMS = {
      # We use temperature of 0.0 because it gives the most predictable, factual answer.
      "temperature": 0.0,
      "max_tokens": 150,
      "model": COMPLETIONS_MODEL,
  }

  def create
    question_asked = params[:question] || ""

    if not question_asked.end_with?("?")
      question_asked += "?"
    end

    previous_question = Question.where(:question => question_asked).first
    audio_src_url = nil
    if previous_question and previous_question.audio_src_url
      audio_src_url = previous_question.audio_src_url
    end

    if not audio_src_url.nil?
      p "previously asked and answered: #{previous_question.answer} ( #{previous_question.audio_src_url} )"
      previous_question.ask_count = previous_question.ask_count + 1
      previous_question.save()
      return render :json => {
        "question": previous_question.question,
        "answer": previous_question.answer,
        "audio_src_url": audio_src_url,
        "id": previous_question.id
      }
    end

    project_uuid = ENV['RESEMBLE_PROJECT_UUID']
    voice_uuid = ENV['RESEMBLE_VOICE_UUID']

    if project_uuid and voice_uuid
      response = Resemble::V2::Clip.create_sync(
        project_uuid,
        voice_uuid,
        question_asked,
        title: nil,
        sample_rate: nil,
        output_format: nil,
        precision: nil,
        include_timestamps: nil,
        is_public: nil,
        is_archived: nil,
        raw: nil
      )
    end

    df = Rover::DataFrame.new()
    page_location = ENV['PAGES_CSV_ABSOLUTE_PATH']
    if page_location
      df = Rover.read_csv(page_location)
    end

    document_embeddings = {}
    page_embeddings_location = ENV['PAGES_EMBEDDINGS_CSV_ABSOLUTE_PATH']
    if page_embeddings_location
      document_embeddings = load_embeddings(page_embeddings_location)
    end

    answer, context = answer_query_with_context(question_asked, df, document_embeddings)

    question = Question.create(question: question_asked, answer: answer, context: context, audio_src_url: "")
    question.save!()

    render :json => {
      "question": question.question,
      "answer": question.answer,
      "audio_src_url": question.audio_src_url,
      "id": question.id
    }
  end

  def show
    question = Question.find(params[:id])
    render :json => {
      "question": question.question,
      "answer": question.answer,
      "audio_src_url": question.audio_src_url,
      "id": question.id
    }
  end

  private
  def client
    @client ||= OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY']) 
  end

  def get_embedding(text, model)
    result = client.embeddings(
      parameters: {
        model: model,
        input: text
      }
    )

    result['data'][0]['embedding']
  end

  def get_doc_embedding(text)
    get_embedding(text, DOC_EMBEDDINGS_MODEL)
  end

  def get_query_embedding(text)
    get_embedding(text, QUERY_EMBEDDINGS_MODEL)
  end

  def vector_similarity(x, y)
    # We could use cosine similarity or dot product to calculate the similarity between vectors.
    # In practice, we have found it makes little difference.
    Vector.send(:new, x).inner_product(Vector.send(:new, y))
  end

  def order_document_sections_by_query_similarity(query, contexts)
    # Find the query embedding for the supplied query, and compare it against all of the pre-calculated document embeddings
    # to find the most relevant sections.

    # Return the list of document sections, sorted by relevance in descending order.
    query_embedding = get_query_embedding(query)

    document_similarities = []
    contexts.each do |doc_index, doc_embedding|
      document_similarities.push({embedding: vector_similarity(query_embedding, doc_embedding), title: doc_index})
    end

    document_similarities.sort_by { |hsh| hsh[:embedding] }.reverse!
  end

  def load_embeddings(fname)
    # Read the document embeddings and their keys from a CSV.

    # fname is the path to a CSV with exactly these named columns:
    #     "title", "0", "1", ... up to the length of the embedding vectors.

    df = Rover.read_csv(fname)
    max_dim = df.keys.select { |c| c != "title" }.map{ |c| c.to_i }.max
    final_result = {}
    df.each_row do |row|
      current_row_items = []
      (0..max_dim).each { |i| current_row_items.push(row[i.to_s]) }
      final_result[row["title"]] = current_row_items
    end
    return final_result
  end

  def construct_prompt(question, context_embeddings, df)
    # Fetch relevant embeddings
    most_relevant_document_sections = order_document_sections_by_query_similarity(question, context_embeddings)

    chosen_sections = []
    chosen_sections_len = 0
    chosen_sections_indexes = []

    # for section_index in most_relevant_document_sections do
    most_relevant_document_sections.each do |section|
        section_index = section[:title]
        document_section = df[df['title'] == section_index]

        chosen_sections_len += document_section['tokens'][0] + SEPARATOR_LEN
        if chosen_sections_len > MAX_SECTION_LEN
          space_left = MAX_SECTION_LEN - chosen_sections_len - SEPARATOR.length
          chosen_sections.push(SEPARATOR + document_section['content'][0][:space_left])
          chosen_sections_indexes.push(str(section_index))
          break
        end

        chosen_sections.push(SEPARATOR + document_section['content'][0])
        chosen_sections_indexes.push(section_index.to_s)
    end

    header = """Sahil Lavingia is the founder and CEO of Gumroad, and the author of the book The Minimalist Entrepreneur (also known as TME). These are questions and answers by him. Please keep your answers to three sentences maximum, and speak in complete sentences. Stop speaking once your point is made.\n\nContext that may be useful, pulled from The Minimalist Entrepreneur:\n"""

    question_1 = "\n\n\nQ: How to choose what business to start?\n\nA: First off don't be in a rush. Look around you, see what problems you or other people are facing, and solve one of these problems if you see some overlap with your passions or skills. Or, even if you don't see an overlap, imagine how you would solve that problem anyway. Start super, super small."
    question_2 = "\n\n\nQ: Q: Should we start the business on the side first or should we put full effort right from the start?\n\nA:   Always on the side. Things start small and get bigger from there, and I don't know if I would ever “fully” commit to something unless I had some semblance of customer traction. Like with this product I'm working on now!"
    question_3 = "\n\n\nQ: Should we sell first than build or the other way around?\n\nA: I would recommend building first. Building will teach you a lot, and too many people use “sales” as an excuse to never learn essential skills like building. You can't sell a house you can't build!"
    question_4 = "\n\n\nQ: Andrew Chen has a book on this so maybe touché, but how should founders think about the cold start problem? Businesses are hard to start, and even harder to sustain but the latter is somewhat defined and structured, whereas the former is the vast unknown. Not sure if it's worthy, but this is something I have personally struggled with\n\nA: Hey, this is about my book, not his! I would solve the problem from a single player perspective first. For example, Gumroad is useful to a creator looking to sell something even if no one is currently using the platform. Usage helps, but it's not necessary."
    question_5 = "\n\n\nQ: What is one business that you think is ripe for a minimalist Entrepreneur innovation that isn't currently being pursued by your community?\n\nA: I would move to a place outside of a big city and watch how broken, slow, and non-automated most things are. And of course the big categories like housing, transportation, toys, healthcare, supply chain, food, and more, are constantly being upturned. Go to an industry conference and it's all they talk about! Any industry…"
    question_6 = "\n\n\nQ: How can you tell if your pricing is right? If you are leaving money on the table\n\nA: I would work backwards from the kind of success you want, how many customers you think you can reasonably get to within a few years, and then reverse engineer how much it should be priced to make that work."
    question_7 = "\n\n\nQ: Why is the name of your book 'the minimalist entrepreneur' \n\nA: I think more people should start businesses, and was hoping that making it feel more “minimal” would make it feel more achievable and lead more people to starting-the hardest step."
    question_8 = "\n\n\nQ: How long it takes to write TME\n\nA: About 500 hours over the course of a year or two, including book proposal and outline."
    question_9 = "\n\n\nQ: What is the best way to distribute surveys to test my product idea\n\nA: I use Google Forms and my email list / Twitter account. Works great and is 100% free."
    question_10 = "\n\n\nQ: How do you know, when to quit\n\nA: When I'm bored, no longer learning, not earning enough, getting physically unhealthy, etc… loads of reasons. I think the default should be to “quit” and work on something new. Few things are worth holding your attention for a long period of time."

    prompt = (header + chosen_sections.join("") + question_1 + question_2 + question_3 + question_4 + question_5 + question_6 + question_7 + question_8 + question_9 + question_10 + "\n\n\nQ: " + question + "\n\nA: ")
    context = chosen_sections.join("")

    return prompt, context
  end

  def answer_query_with_context(query, df, document_embeddings)
    prompt, context = construct_prompt(
        query,
        document_embeddings,
        df
    )

    print("===\n", prompt)

    response = client.completions(
      parameters: {
          prompt: prompt,
          **COMPLETIONS_API_PARAMS
      })

    return response["choices"][0]["text"].strip, context
  end
end
