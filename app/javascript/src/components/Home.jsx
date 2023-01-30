import React, { useState } from "react";
import "./Home.css";

const Home = () => {
  const [question, setQuestion] = useState("");
  const [showActionButtons, setShowActionButtons] = useState(true);
  const [answerToShow, setAnswerToShow] = useState("");

  const typeWritingEffect = (originalAnswer, previousAnswer, start, end) => {
    // If we reached the length of original answer, just stop here instead of calling the function again
    if (end === originalAnswer.length) {
      setShowActionButtons(true);
      return;
    }
    setTimeout(() => {
      const newAnswer = previousAnswer + originalAnswer.substring(start, end);
      setAnswerToShow(newAnswer);
      typeWritingEffect(originalAnswer, newAnswer, end, end + 1);
    }, 100);
  };

  const askQuestion = () => {
    if (answerToShow) {
      setAnswerToShow("");
      return;
    }

    let formData = new FormData();
    formData.append("question", question);

    fetch("/api/v1/ask/create", {
      method: "POST",
      body: formData,
    })
      .then((data) => data.json())
      .then((data) => {
        if (data?.answer) {
          setShowActionButtons(false);
          typeWritingEffect(data.answer, "", 0, 1);
        }
      })
      .catch(() => {});
  };

  return (
    <div className="home-container">
      <textarea onChange={(e) => setQuestion(e.target.value)} />
      {answerToShow && (
        <div className="answer-container">
          <strong>Answer: </strong>
          <span>{answerToShow}</span>
        </div>
      )}
      {showActionButtons && (
        <div className="buttons-container">
          <button className="ask-question" onClick={askQuestion}>
            Ask {answerToShow ? "another" : ""} question
          </button>
          {!answerToShow && (
            <button className="feeling-luck">I'm feeling lucky</button>
          )}
        </div>
      )}
    </div>
  );
};

export default Home;
