import React, { useState, useEffect, useMemo, Fragment } from 'react';
import { useParams } from 'react-router-dom';
import { supabase } from '../supabaseClient';

const MATCH_WIDTH = 150;
const MATCH_HEIGHT = 100;
const VERTICAL_GAP = 20;
const HORIZONTAL_GAP = 40;
const HEADER_HEIGHT = 64;

const calculateBracketLayout = (draw) => {
  if (!draw) return { rounds: [], lines: [], bracketDimensions: { width: 0, height: 0 } };

  const positionedRounds = [];
  const lines = [];
  const roundNumbers = Object.keys(draw).map(Number).sort((a, b) => a - b);
  let maxBracketHeight = 0;

  roundNumbers.forEach((roundNum, roundIndex) => {
    const roundMatches = draw[roundNum];
    const positionedMatches = [];
    const roundLeft = roundIndex * (MATCH_WIDTH + HORIZONTAL_GAP);

    roundMatches.forEach((match, matchIndex) => {
      let matchTop;
      if (roundIndex === 0) {
        matchTop = HEADER_HEIGHT + matchIndex * (MATCH_HEIGHT + VERTICAL_GAP);
      } else {
        const prevRound = positionedRounds[roundIndex - 1];
        const parent1 = prevRound?.matches[matchIndex * 2];
        const parent2 = prevRound?.matches[matchIndex * 2 + 1];

        if (parent1 && parent2) {
          const parent1CenterY = parent1.top + (MATCH_HEIGHT / 2);
          const parent2CenterY = parent2.top + (MATCH_HEIGHT / 2);
          matchTop = (parent1CenterY + parent2CenterY) / 2 - (MATCH_HEIGHT / 2);
        } else {
          matchTop = matchIndex * (MATCH_HEIGHT + VERTICAL_GAP * Math.pow(2, roundIndex));
        }
      }
      
      positionedMatches.push({ ...match, top: matchTop, left: roundLeft });
      const currentHeight = matchTop + MATCH_HEIGHT;
      if (currentHeight > maxBracketHeight) {
        maxBracketHeight = currentHeight;
      }
    });
    
    positionedRounds.push({ roundNum, matches: positionedMatches });
  });

  positionedRounds.forEach((round, roundIndex) => {
    if (roundIndex > 0) {
      const prevRound = positionedRounds[roundIndex - 1];
      round.matches.forEach((match, matchIndex) => {
        const parent1 = prevRound.matches[matchIndex * 2];
        const parent2 = prevRound.matches[matchIndex * 2 + 1];

        if (parent1 && parent2) {
          const p1_x_end = parent1.left + MATCH_WIDTH;
          const p1_y_mid = parent1.top + MATCH_HEIGHT / 2;
          
          const p2_y_mid = parent2.top + MATCH_HEIGHT / 2;

          const child_x_start = match.left;
          const child_y_mid = match.top + MATCH_HEIGHT / 2;
          
          const meeting_x = child_x_start - HORIZONTAL_GAP / 2;

          lines.push({ x1: p1_x_end, y1: p1_y_mid, x2: meeting_x, y2: p1_y_mid, key: `h-p1-${match.id}`});
          lines.push({ x1: p1_x_end, y1: p2_y_mid, x2: meeting_x, y2: p2_y_mid, key: `h-p2-${match.id}`});
          lines.push({ x1: meeting_x, y1: p1_y_mid, x2: meeting_x, y2: p2_y_mid, key: `v-m-${match.id}`});
          lines.push({ x1: meeting_x, y1: child_y_mid, x2: child_x_start, y2: child_y_mid, key: `h-c-${match.id}`});
        }
      });
    }
  });
  
  const bracketWidth = (roundNumbers.length * (MATCH_WIDTH + HORIZONTAL_GAP)) - HORIZONTAL_GAP;
  return { 
    rounds: positionedRounds, 
    lines, 
    bracketDimensions: { width: bracketWidth, height: maxBracketHeight } 
  };
};

const MatchCard = ({ match, getMatchStyle, totalRounds, seedingInfo }) => {
  const { border, background, boxShadow } = getMatchStyle(match);
  const isDoubles = match.entry1_partner_first_name || match.entry2_partner_first_name;
  const isFinals = match.round_number === totalRounds;
  
  const getPlayerDisplay = (firstName, lastName, partnerFirstName, partnerLastName, isWinner, registrationId) => {
    const mainPlayerName = firstName && lastName 
      ? `${firstName} ${lastName}` 
      : match.round_number === 1 ? 'BYE' : 'TBD';
    const partnerName = partnerFirstName && partnerLastName ? `${partnerFirstName} ${partnerLastName}` : null;
    
    // Get seed number if it's round 1 and player is seeded
    const seedNumber = match.round_number === 1 && registrationId && 
      seedingInfo[match.category_id]?.[registrationId];
    
    return (
      <div
        style={{
          fontSize: '13.5px',
          lineHeight: 1.3,
          padding: '2px 4px',
          borderRadius: '4px',
          fontFamily: 'Inter, Roboto, system-ui, -apple-system, sans-serif',
          letterSpacing: '-0.01em',
          display: 'flex',
          alignItems: 'center',
          gap: '4px',
          ...(isWinner && { 
            backgroundColor: '#dcfce7', 
            color: '#166534', 
            fontWeight: '600',
            textShadow: '0 0 1px rgba(22, 101, 52, 0.1)' 
          }),
        }}
      >
        <div style={{ 
          flexGrow: 1,
          overflow: 'hidden'
        }}>
          <div style={{ 
            overflow: 'hidden', 
            textOverflow: 'ellipsis', 
            whiteSpace: 'nowrap',
            fontWeight: '500',
            display: 'flex',
            alignItems: 'center',
            gap: '4px'
          }}>
            {mainPlayerName}
            {seedNumber && (
              <span style={{
                color: '#854d0e',
                fontWeight: '600'
              }}>
                [{seedNumber}]
              </span>
            )}
          </div>
          {partnerName && (
            <div style={{ 
              overflow: 'hidden', 
              textOverflow: 'ellipsis', 
              whiteSpace: 'nowrap',
              marginTop: '1px',
              fontWeight: '500',
              color: isWinner ? '#166534' : 'inherit'
            }}>
              {partnerName}
            </div>
          )}
        </div>
        {isFinals && isWinner && (
          <div style={{ 
            flexShrink: 0, 
            fontSize: '24px',
            display: 'flex',
            alignItems: 'center',
            alignSelf: 'stretch'
          }}>
            🏆
          </div>
        )}
      </div>
    );
  };

  const isPlayer1Winner = match.winner_registration_id && match.winner_registration_id === match.entry1_registration_id;
  const isPlayer2Winner = match.winner_registration_id && match.winner_registration_id === match.entry2_registration_id;
  const isBye = match.entry1_registration_id === '00000000-0000-0000-0000-000000000000' || 
                match.entry2_registration_id === '00000000-0000-0000-0000-000000000000';

  return (
    <div
      style={{
        border,
        background,
        boxShadow: boxShadow || '0 1px 3px rgba(0,0,0,0.08)',
        borderRadius: '8px',
        padding: '4px',
        height: `${MATCH_HEIGHT}px`,
        width: `${MATCH_WIDTH}px`,
        display: 'flex',
        flexDirection: 'column',
        justifyContent: isBye ? 'center' : 'space-between',
        transition: 'box-shadow 0.2s, transform 0.2s, background 0.2s',
      }}
    >
      {getPlayerDisplay(
        match.entry1_first_name,
        match.entry1_last_name,
        match.entry1_partner_first_name,
        match.entry1_partner_last_name,
        isPlayer1Winner,
        match.entry1_registration_id
      )}
      {getPlayerDisplay(
        match.entry2_first_name,
        match.entry2_last_name,
        match.entry2_partner_first_name,
        match.entry2_partner_last_name,
        isPlayer2Winner,
        match.entry2_registration_id
      )}
    </div>
  );
};

function SingleEliminationBracketView() {
  const { id: tournamentId } = useParams();
  const [categories, setCategories] = useState([]);
  const [selectedCategory, setSelectedCategory] = useState(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [generatedDraws, setGeneratedDraws] = useState({});
  const [drawsSubmitted, setDrawsSubmitted] = useState(false);
  const [tournament, setTournament] = useState(null);
  const [seedingInfo, setSeedingInfo] = useState({});

  const { rounds, lines, bracketDimensions } = useMemo(() => {
    const draw = generatedDraws[selectedCategory];
    return calculateBracketLayout(draw);
  }, [selectedCategory, generatedDraws]);

  const fetchDrawsAndSeeding = async () => {
    try {
      if (!drawsSubmitted) {
        setLoading(false);
        return;
      }
      // Fetch match data from public view
      const { data: matches, error: matchesError } = await supabase
        .from('public_single_elimination_brackets')
        .select('*')
        .eq('tournament_id', tournamentId)
        .order('round_number', { ascending: true })
        .order('match_number', { ascending: true });

      if (matchesError) throw matchesError;

      // Group matches by category and round
      const matchesByCategory = {};
      matches.forEach(match => {
        if (!matchesByCategory[match.category_id]) matchesByCategory[match.category_id] = {};
        if (!matchesByCategory[match.category_id][match.round_number]) matchesByCategory[match.category_id][match.round_number] = [];
        matchesByCategory[match.category_id][match.round_number].push(match);
      });
      setGeneratedDraws(matchesByCategory);
      setLoading(false);
    } catch (err) {
      setLoading(false);
      console.error('Failed to fetch bracket data:', err);
    }
  };

  useEffect(() => {
    fetchDrawsAndSeeding();
  }, [drawsSubmitted, tournamentId]);

  useEffect(() => {
    const fetchTournament = async () => {
      try {
        // Get tournament info and categories from the public view
        const { data: matches, error: matchesError } = await supabase
          .from('public_single_elimination_brackets')
          .select('tournament_id, tournament_name, tournament_status, category_id, category_gender, category_type, category_age_group')
          .eq('tournament_id', tournamentId);

        if (matchesError) throw matchesError;
        if (matches && matches.length > 0) {
          // Extract unique categories with their full info
          const uniqueCategories = Array.from(
            new Set(matches.map(m => JSON.stringify({
              id: m.category_id,
              gender: m.category_gender,
              type: m.category_type,
              ageGroup: m.category_age_group
            })))
          ).map(str => JSON.parse(str));

          const tournament = {
            name: matches[0].tournament_name,
            status: matches[0].tournament_status,
            categories: uniqueCategories
          };
          
          setTournament(tournament);
          setCategories(uniqueCategories);
          setDrawsSubmitted(true);
          if (uniqueCategories.length > 0) {
            setSelectedCategory(uniqueCategories[0].id);
          }
        }
      } catch (err) {
        console.error('Error fetching tournament:', err);
        setError('Failed to load tournament');
      }
    };

    fetchTournament();
  }, [tournamentId]);

  const getMatchStyle = (match) => {
    const now = new Date();
    
    // Completed or Walkover
    if (match.status === 'completed' || match.status === 'walkover') {
      return {
        border: '3px solid #16a34a',
        background: '#f6fef9', // very subtle green tint
      };
    }
    
    // Scheduled but overdue (double border: red outer, blue inner)
    if (match.status === 'scheduled' && match.deadline && new Date(match.deadline) < now) {
      return {
        border: '4px solid #dc2626', // Red outer border
        boxShadow: 'inset 0 0 0 2px #2563eb', // Blue inner border using inset shadow
        background: '#f6f8fe', // very subtle blue tint
      };
    }
    
    // Overdue (explicit status or deadline in the past, not completed or walkover)
    if (match.status === 'overdue' || (match.deadline && new Date(match.deadline) < now && match.status !== 'completed' && match.status !== 'walkover' && match.status !== 'scheduled')) {
      return {
        border: '3px solid #dc2626',
        background: '#fef6f6', // very subtle red tint
      };
    }
    
    // Scheduled (status is 'scheduled')
    if (match.status === 'scheduled') {
      return {
        border: '3px solid #2563eb',
        background: '#f6f8fe', // very subtle blue tint
      };
    }
    
    // Ready (both players assigned, awaiting_date)
    if (
      match.entry1_registration_id &&
      match.entry2_registration_id &&
      match.status === 'awaiting_date'
    ) {
      return {
        border: '3px solid #ca8a04', // yellow-600 instead of orange
        background: '#fefce8', // yellow-50 instead of orange tint
      };
    }
    
    // Default
    return {
      border: '2px solid #d1d5db',
      background: '#fff',
    };
  };

  const renderBracket = (categoryId) => {
    if (!categoryId || !generatedDraws[categoryId] || rounds.length === 0) {
      return null;
    }

    const overdueCount = rounds.flatMap(r => r.matches).filter(match => 
      match.status === 'overdue' || 
      (match.deadline && new Date(match.deadline) < new Date() && 
        match.status !== 'completed' && match.status !== 'walkover')
    ).length;
    
    return (
      <div className="mt-8">
        <h3 className="text-xl font-semibold mb-2">Tournament Bracket - {
          selectedCategory?.split('_').map(word => 
            word.charAt(0).toUpperCase() + word.slice(1)
          ).join(' ')
        }</h3>
        {overdueCount > 0 && (
          <div className="mb-4 p-3 bg-red-50 border border-red-200 rounded-lg">
            <div className="flex items-center text-red-800">
              <span className="text-lg mr-2">⚠️</span>
              <span className="font-semibold">{overdueCount} match{overdueCount !== 1 ? 'es' : ''} overdue</span>
            </div>
          </div>
        )}
        {/* Match Status Legend */}
        <div className="mb-4">
          <div className="text-xs sm:text-sm text-gray-600 mb-2">Match Status Guide:</div>
          <div className="flex gap-1 sm:gap-2 overflow-x-auto pb-2">
            <div className="min-w-[90px] sm:min-w-[115px] h-[40px] sm:h-[46px] flex items-center justify-center"><div className="w-full h-[32px] sm:h-[37px] border-2 border-gray-300 bg-white rounded flex items-center justify-center"><span className="text-[10px] sm:text-[12px]">Not Scheduled</span></div></div>
            <div className="min-w-[90px] sm:min-w-[115px] h-[40px] sm:h-[46px] flex items-center justify-center"><div className="w-full h-[32px] sm:h-[37px] border-[3px] border-blue-600 bg-blue-50 rounded flex items-center justify-center"><span className="text-[10px] sm:text-[12px]">Scheduled</span></div></div>
            <div className="min-w-[90px] sm:min-w-[115px] h-[40px] sm:h-[46px] flex items-center justify-center"><div className="w-full h-[32px] sm:h-[37px] border-[3px] border-green-500 bg-green-50 rounded flex items-center justify-center"><span className="text-[10px] sm:text-[12px]">Completed</span></div></div>
            <div className="min-w-[90px] sm:min-w-[115px] h-[40px] sm:h-[46px] flex items-center justify-center"><div className="w-full h-[32px] sm:h-[37px] border-[3px] border-red-600 bg-red-50 rounded flex items-center justify-center"><span className="text-[10px] sm:text-[12px]">Overdue</span></div></div>
            <div className="min-w-[90px] sm:min-w-[115px] h-[40px] sm:h-[46px] flex items-center justify-center"><div className="w-full h-[32px] sm:h-[37px] border-[4px] border-red-600 shadow-[inset_0_0_0_2px_#2563eb] bg-blue-50 rounded flex items-center justify-center"><span className="text-[10px] sm:text-[12px]">Scheduled & Overdue</span></div></div>
            <div className="min-w-[90px] sm:min-w-[115px] h-[40px] sm:h-[46px] flex items-center justify-center"><div className="w-full h-[32px] sm:h-[37px] border-[3px] border-yellow-600 bg-yellow-50 rounded flex items-center justify-center"><span className="text-[10px] sm:text-[12px]">Ready to Schedule</span></div></div>
          </div>
        </div>
        <div className="relative overflow-x-auto p-2 sm:p-4 bg-gray-50 rounded-lg bracket-container" style={{ height: bracketDimensions.height + 20, width: bracketDimensions.width + 20 }}>
          {lines.map(line => {
            const isHorizontal = line.y1 === line.y2;
            const isVertical = line.x1 === line.x2;
            const style = {
              left: `${Math.min(line.x1, line.x2)}px`,
              top: `${Math.min(line.y1, line.y2)}px`,
              width: `${Math.abs(line.x1 - line.x2)}px`,
              height: `${Math.abs(line.y1 - line.y2)}px`,
            };
            if (isHorizontal) { style.height = '2px'; style.top = `${line.y1 - 1}px`; }
            if (isVertical) { style.width = '2px'; style.left = `${line.x1 - 1}px`; }
            return <div key={line.key} className="absolute bg-gray-400" style={style} />;
          })}
          {rounds.map((round) => (
            <Fragment key={round.roundNum}>
              <div className="absolute text-center" style={{ left: round.matches[0].left, top: 0, width: MATCH_WIDTH, height: HEADER_HEIGHT }}>
                <div className="text-lg font-bold text-gray-800">Round {round.roundNum}</div>
                {round.matches[0]?.deadline && <div className="text-sm text-gray-600 mt-1">Deadline: {new Date(round.matches[0].deadline).toLocaleDateString()}</div>}
              </div>
              {round.matches.map(match => (
                <div key={match.id} className="absolute" style={{ top: match.top, left: match.left }}>
                  <MatchCard 
                    match={match} 
                    getMatchStyle={getMatchStyle} 
                    totalRounds={rounds.length}
                    seedingInfo={seedingInfo}
                  />
                </div>
              ))}
            </Fragment>
          ))}
        </div>
      </div>
    );
  };

  if (loading) {
    return <div className="text-center py-8">Loading...</div>;
  }
  if (error) {
    return <div className="text-center py-8 text-red-600">{error}</div>;
  }
  if (!drawsSubmitted) {
    return <div className="text-center py-8 text-gray-600">Draws have not been launched yet for this tournament.</div>;
  }
  return (
    <div className="max-w-6xl mx-auto p-4 sm:p-6">
      <div className="flex justify-between items-center mb-6 sm:mb-8">
        <div>
          <h1 className="text-xl sm:text-2xl font-bold">{tournament?.name} - Status Tracker</h1>
          <div className="text-gray-600 mt-1 text-sm sm:text-base">{tournament?.status}</div>
        </div>
      </div>
      {/* Category Filters */}
      <div className="flex gap-2 sm:gap-3 mb-4 sm:mb-6 overflow-x-auto pb-2">
        {categories.map((category) => (
          <button
            key={category.id}
            onClick={() => setSelectedCategory(category.id)}
            className={`px-3 sm:px-4 py-2 rounded-lg text-xs sm:text-sm font-medium min-w-[80px] sm:min-w-[100px] shadow-sm transition-all duration-200 ${
              selectedCategory === category.id
                ? 'bg-green-50 text-green-700 ring-2 ring-green-500 ring-offset-2'
                : 'bg-gray-100 text-gray-600 hover:bg-gray-200 border border-gray-200'
            }`}
          >
            <span className="capitalize">{category.gender} {category.type}</span><br />
            <span className="capitalize">{category.ageGroup || 'Open'}</span>
          </button>
        ))}
      </div>
      {/* Bracket Display */}
      {selectedCategory && renderBracket(selectedCategory)}
    </div>
  );
}

export default SingleEliminationBracketView; 
 
 