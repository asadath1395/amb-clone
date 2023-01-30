# frozen_string_literal: true

require 'dotenv/load'
require 'optparse'
require 'pdf-reader'
require 'tokenizers'
require 'ruby/openai'
require 'rover-df' # Dataframe and its associated functionalities
require 'csv' # To output into a csv file

COMPLETIONS_MODEL = 'text-davinci-003'

MODEL_NAME = 'curie'

DOC_EMBEDDINGS_MODEL = "text-search-#{MODEL_NAME}-doc-001".freeze

$client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])

options = {}
OptionParser.new do |opts|
  opts.banner = 'Usage: ruby scripts/pdf_to_pages_embeddings.rb [options]'

  opts.on('-pdf', '--pdf', 'Name of PDF') do |pdf_name|
    options[:pdf_name] = pdf_name
  end
end.parse!

filename = options[:pdf_name]

raise OptionParser::MissingArgument if filename.nil?

$tokenizer = Tokenizers.from_pretrained('gpt2')

# Count the number of tokens in a string
def count_tokens(text)
  $tokenizer.encode(text).ids.length
end

# Extract the text from the page
def extract_pages(page_text, index)
  return [] if page_text.empty?

  content = page_text.split.join(' ')
  print("page text: #{content}")
  Rover::DataFrame.new({
                         title: "Page #{index}",
                         content: content,
                         tokens: count_tokens(content) + 4
                       })
end

reader = PDF::Reader.new(filename)
df = Rover::DataFrame.new
reader.pages.each_with_index do |page, index|
  df += extract_pages(page.text, index + 1)
end
df = df[df[:tokens] < 2046]

def get_embedding(text, model)
  result = $client.embeddings(
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

# Create an embedding for each row in the dataframe using the OpenAI Embeddings API. Return a dictionary
# that maps between each embedding vector and the index of the row that it corresponds to.
def compute_doc_embeddings(dataframe)
  final_result = {}
  i = 0
  dataframe.each_row do |row|
    final_result[i] = get_doc_embedding(row[:content])
    i += 1
  end
  final_result
end
# CSV with exactly these named columns:
# "title", "0", "1", ... up to the length of the embedding vectors.

doc_embeddings = compute_doc_embeddings(df)

CSV.open("#{filename}.embeddings.csv", 'w') do |csv|
  csv << ['title'] + (0...4096).to_a
  doc_embeddings.each do |i, embedding|
    csv << ["Page #{i + 1}"] + embedding
  end
end
