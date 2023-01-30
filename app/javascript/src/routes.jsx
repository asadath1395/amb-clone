import React from "react";
import { BrowserRouter as Router, Routes, Route } from "react-router-dom";
import Home from "./components/Home";

export default (
  <Router>
    <Routes>
      <Route path="/" exact element={<Home />} />
      <Route path="/question/:id" element={<Home />} />
    </Routes>
  </Router>
);
