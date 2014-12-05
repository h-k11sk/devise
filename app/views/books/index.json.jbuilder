json.array!(@books) do |book|
  json.extract! book, :title, :author, :review, :description
  json.url book_url(book, format: :json)
end