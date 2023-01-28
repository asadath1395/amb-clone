require "dotenv/load"
require "optparse"
require "pdf-reader"
require "tokenizers"
require "ruby/openai"
require "rover-df" # Dataframe and its associated functionalities
require "csv" # To output into a csv file

COMPLETIONS_MODEL = "text-davinci-003"

MODEL_NAME = "curie"

DOC_EMBEDDINGS_MODEL = "text-search-#{MODEL_NAME}-doc-001"

$client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])

options = {}
OptionParser.new do |opts|
  opts.banner = "Usage: ruby scripts/pdf_to_pages_embeddings.rb [options]"

  opts.on("-pdf", "--pdf", "Name of PDF") do |pdf_name|
    options[:pdf_name] = pdf_name
  end
end.parse!

filename = options[:pdf_name]

$tokenizer = Tokenizers.from_pretrained("gpt2")

def count_tokens(text)
  """count the number of tokens in a string"""
  return $tokenizer.encode(text).ids.length
end

def extract_pages(page_text, index)
  """
  Extract the text from the page
  """
  if page_text.length == 0
    return []
  end

  # print("page text: " + content)
  content = page_text.split().join(" ")
  outputs = Rover::DataFrame.new({
    title: "Page #{index.to_s}",
    content: content,
    tokens: count_tokens(content)+4
  })

  return outputs
end

reader = PDF::Reader.new(filename)
df = Rover::DataFrame.new()
reader.pages.each_with_index do |page, index|
  df += extract_pages(page.text, index+1)
end
df = df[df[:tokens]<2046]

def get_embedding(text, model)
  result = $client.embeddings(
    parameters: {
        model: model,
        input: text
    }
  )

  return result["data"][0]["embedding"]
end

def get_doc_embedding(text)
  return get_embedding(text, DOC_EMBEDDINGS_MODEL)
end

def compute_doc_embeddings(df)
  """
  Create an embedding for each row in the dataframe using the OpenAI Embeddings API.

  Return a dictionary that maps between each embedding vector and the index of the row that it corresponds to.
  """
  finalResult = {}
  i = 0
  df.each_row do |row|
    finalResult[i] = get_doc_embedding(row[:content])
    i += 1
  end
  return finalResult
end
# CSV with exactly these named columns:
# "title", "0", "1", ... up to the length of the embedding vectors.

doc_embeddings = compute_doc_embeddings(df)

CSV.open("#{filename}.new.embeddings.csv", 'w') do |csv|
  csv << ["title"] + (0...4096).to_a
  doc_embeddings.each do |i, embedding|
    csv << ["Page #{i + 1}"] + embedding
  end
end
