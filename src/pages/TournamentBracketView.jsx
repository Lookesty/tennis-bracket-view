import React, { useState, useEffect } from 'react';
import { useParams } from 'react-router-dom';
import { supabase } from '../supabaseClient';
import SingleEliminationBracketView from './SingleEliminationBracketView';
import RoundRobinBracketView from './RoundRobinBracketView';

function TournamentBracketView() {
  const { id: tournamentId } = useParams();
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [format, setFormat] = useState(null);

  useEffect(() => {
    const fetchTournamentFormat = async () => {
      try {
        const { data, error } = await supabase
          .from('tennis_events')
          .select('format')
          .eq('id', tournamentId)
          .single();

        if (error) throw error;
        setFormat(data.format);
        setLoading(false);
      } catch (err) {
        console.error('Error fetching tournament format:', err);
        setError('Failed to load tournament format');
        setLoading(false);
      }
    };

    fetchTournamentFormat();
  }, [tournamentId]);

  if (loading) return <div>Loading...</div>;
  if (error) return <div>Error: {error}</div>;

  return format === 'round_robin' ? 
    <RoundRobinBracketView tournamentId={tournamentId} /> : 
    <SingleEliminationBracketView tournamentId={tournamentId} />;
}

export default TournamentBracketView; 