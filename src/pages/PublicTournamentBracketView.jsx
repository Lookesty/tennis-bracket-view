import React, { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { publicSupabase as supabase } from '../supabaseClient';
import SingleEliminationBracketView from './SingleEliminationBracketView';
import RoundRobinBracketView from './RoundRobinBracketView';

function PublicTournamentBracketView() {
  const { tournamentId } = useParams();
  const [tournament, setTournament] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);

  useEffect(() => {
    const fetchTournament = async () => {
      try {
        const { data, error } = await supabase
          .from('tennis_events')
          .select('name, format, status')
          .eq('id', tournamentId)
          .single();

        if (error) throw error;
        setTournament(data);
      } catch (err) {
        console.error('Error fetching tournament:', err);
        setError('Tournament not found or not accessible');
      } finally {
        setLoading(false);
      }
    };

    fetchTournament();
  }, [tournamentId]);

  if (loading) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="animate-spin rounded-full h-8 w-8 border-t-2 border-b-2 border-blue-500"></div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-red-500">{error}</div>
      </div>
    );
  }

  if (!tournament) {
    return (
      <div className="flex items-center justify-center min-h-screen">
        <div className="text-gray-500">Tournament not found</div>
      </div>
    );
  }

  return (
    <div className="container mx-auto px-4 py-8">
      <div className="mb-8">
        <h1 className="text-2xl font-bold">{tournament.name} - Status Tracker</h1>
        <div className="text-gray-600 mt-1">{tournament.status}</div>
      </div>

      {tournament.format === 'single_elimination' ? (
        <SingleEliminationBracketView isPublic={true} />
      ) : (
        <RoundRobinBracketView isPublic={true} />
      )}
    </div>
  );
}

export default PublicTournamentBracketView; 