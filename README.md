# README

This is a clone of the implementation of https://askmybook.com/ (https://github.com/slavingia/askmybook) done using Ruby (v3.2.0) on Rails (v7.0.4.2) and React (v18.2.0). The original implementation is using Python and Django which has been ported to RoR and React.

## Setup

1. Copy the contents of `.env.example` and create a new file `.env`
2. Fill in all the details. `OPENAI_API_KEY` is the only required param rest all are optional.
3. Install required packages by running
   `bundle install` and `yarn install`
4. Turn your PDF into embeddings for GPT-3:
   `ruby scripts/pdf_to_pages_embeddings.rb --pdf sample.pdf`
5. Setup database tables by running the following commands

```
bin/rails db:create
bin/rails db:migrate
```

6. Run `bin/dev` which will spin up both Rails and React JS
