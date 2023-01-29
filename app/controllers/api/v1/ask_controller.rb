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

    question = Question.create(question: question_asked, answer: question_asked, audio_src_url: "")
    question.save!()

    render :json => {
      "question": question.question,
      "answer": question.answer,
      "audio_src_url": question.audio_src_url,
      "id": question.id
    }
  end
end
