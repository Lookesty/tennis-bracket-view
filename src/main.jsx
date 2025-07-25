import React from "react";
import ReactDOM from "react-dom/client";
import { createBrowserRouter, RouterProvider } from "react-router-dom";
import "./index.css";
import TournamentDirectory from "./pages/TournamentDirectory";
import TournamentBracketView from "./pages/TournamentBracketView";

// Create router configuration
const router = createBrowserRouter([
  {
    path: "/",
    element: <TournamentDirectory />,
  },
  {
    path: "/:id",
    element: <TournamentBracketView />,
  }
]);

ReactDOM.createRoot(document.getElementById("root")).render(
  <React.StrictMode>
      <RouterProvider router={router} />
  </React.StrictMode>
);
