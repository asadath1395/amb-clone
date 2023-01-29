require 'dotenv/load'
require 'resemble'

Resemble.api_key = ENV["RESEMBLE_API_KEY"]

class Api::V1::AskController < ApplicationController
  skip_forgery_protection

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

    p previous_question, audio_src_url
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

    project_uuid = 'adb8d364'
    voice_uuid = 't6551qa8'

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

    question = Question.create(question: question_asked, answer: question_asked, audio_src_url: response["item"])
    question.save!()

    render :json => {
      "question": question.question,
      "answer": question.answer,
      "audio_src_url": question.audio_src_url,
      "id": question.id
    }
  end
end
