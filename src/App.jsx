import React from "react";
import { Routes, Route } from "react-router-dom";
import TournamentDirectory from "./pages/TournamentDirectory";
import TournamentBracketView from "./pages/TournamentBracketView";

export default function App() {
  return (
    <Routes>
      <Route path="/" element={<TournamentDirectory />} />
      <Route path="/:id" element={<TournamentBracketView />} />
    </Routes>
  );
}

