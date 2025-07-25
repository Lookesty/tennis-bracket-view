# Tennis Bracket Viewer

A public tournament bracket viewer for tennis tournaments. View live tournament brackets, standings, and match results.

## Features

- **Tournament Directory** - Browse all available tournaments
- **Single Elimination Brackets** - View tournament brackets with match results
- **Round Robin Standings** - View group standings and match schedules
- **Public Access** - No registration required to view tournaments
- **Responsive Design** - Works on desktop and mobile devices

## Tech Stack

- **Frontend**: React, Vite, Tailwind CSS
- **Backend**: Supabase (PostgreSQL)
- **Deployment**: Vercel

## Getting Started

### Prerequisites

- Node.js (v16 or higher)
- npm or yarn

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/tennis-bracket-view.git
cd tennis-bracket-view
```

2. Install dependencies:
```bash
npm install
```

3. Set up environment variables:
Create a `.env` file with your Supabase credentials:
```
VITE_SUPABASE_URL=your_supabase_url
VITE_SUPABASE_ANON_KEY=your_supabase_anon_key
```

4. Run the development server:
```bash
npm run dev
```

5. Open [http://localhost:5173](http://localhost:5173) in your browser.

## Deployment

This project is configured for deployment on Vercel. The `vercel.json` file contains the necessary configuration.

## Database Setup

The database schema is managed through Supabase migrations in the `supabase/migrations/` directory.

## License

MIT License 