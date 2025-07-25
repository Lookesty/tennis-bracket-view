import React, { useState, useEffect } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { supabase } from '../supabaseClient';
import RoundRobinStandings from '../components/RoundRobinStandings';

const MATCH_WIDTH = 150;
const MATCH_HEIGHT = 100;

const MatchCard = ({ match, getMatchStyle }) => {
  try {
    const { border, background, boxShadow } = getMatchStyle(match);
    const isDoubles = match.entry1_partner_first_name || match.entry2_partner_first_name;
    const isFinals = false; // No finals in round robin
    
    const getPlayerDisplay = (firstName, lastName, partnerFirstName, partnerLastName, isWinner) => {
      try {
        const mainPlayerName = firstName && lastName 
          ? `${firstName} ${lastName}` 
          : 'TBD';
        const partnerName = partnerFirstName && partnerLastName ? `${partnerFirstName} ${partnerLastName}` : null;
        
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
                fontWeight: '500'
              }}>
                {mainPlayerName}
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
          </div>
        );
      } catch (error) {
        console.error('Error rendering player display:', error);
        return <div>Error displaying player</div>;
      }
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
          isPlayer1Winner
        )}
        {getPlayerDisplay(
          match.entry2_first_name,
          match.entry2_last_name,
          match.entry2_partner_first_name,
          match.entry2_partner_last_name,
          isPlayer2Winner
        )}
      </div>
    );
  } catch (error) {
    console.error('Error rendering match card:', error);
    return (
      <div
        style={{
          border: '2px solid #d1d5db',
          background: '#fff',
          boxShadow: '0 1px 3px rgba(0,0,0,0.08)',
          borderRadius: '8px',
          padding: '4px',
          height: `${MATCH_HEIGHT}px`,
          width: `${MATCH_WIDTH}px`,
          display: 'flex',
          flexDirection: 'column',
          justifyContent: 'center',
          alignItems: 'center',
        }}
      >
        <div className="text-red-600">Error displaying match</div>
      </div>
    );
  }
};

function RoundRobinBracketView() {
  const { id: tournamentId } = useParams();
  const navigate = useNavigate();
  const [categories, setCategories] = useState([]);
  const [selectedCategory, setSelectedCategory] = useState(null);
  const [selectedGroup, setSelectedGroup] = useState('A');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [generatedDraws, setGeneratedDraws] = useState({});
  const [drawsSubmitted, setDrawsSubmitted] = useState(false);
  const [tournament, setTournament] = useState(null);
  const [standings, setStandings] = useState([]);
  const [standingsLoading, setStandingsLoading] = useState(false);
  const [standingsError, setStandingsError] = useState(null);
  const [groups, setGroups] = useState({});

  const fetchDrawsAndPlayers = async () => {
    try {
      if (!tournamentId) {
        console.error('No tournament ID provided to fetchDrawsAndPlayers');
        setError('No tournament ID provided');
        setLoading(false);
        return;
      }

      console.log('Fetching round robin data for tournament:', tournamentId);
      setLoading(true);
      setError(null);

      // Fetch all data from public view
      const { data: matches, error: matchesError } = await supabase
        .from('public_round_robin_brackets')
        .select('*')
        .eq('tournament_id', tournamentId)
        .order('category_id', { ascending: true })
        .order('group_number', { ascending: true })
        .order('round_number', { ascending: true })
        .order('match_number', { ascending: true });

      if (matchesError) {
        console.error('Error fetching matches:', matchesError);
        setError(matchesError.message || 'Failed to fetch tournament matches');
        setLoading(false);
        return;
      }

      if (!matches || matches.length === 0) {
        console.log('No matches found for tournament:', tournamentId);
        setGeneratedDraws({});
        setLoading(false);
        return;
      }

      // Organize data by category and group
      const matchesByCategory = {};
      const groupsByCategory = {};
      const uniqueCategories = new Set();

      // Process matches and extract categories and groups
      matches.forEach(match => {
        try {
          const categoryId = match.category_id;
          const groupNumber = match.group_number;
          uniqueCategories.add(categoryId);
          
          if (!matchesByCategory[categoryId]) {
            matchesByCategory[categoryId] = {};
          }
          if (!matchesByCategory[categoryId][groupNumber]) {
            matchesByCategory[categoryId][groupNumber] = [];
          }
          matchesByCategory[categoryId][groupNumber].push(match);

          // Store group info
          if (!groupsByCategory[categoryId]) {
            groupsByCategory[categoryId] = {};
          }
          if (!groupsByCategory[categoryId][groupNumber]) {
            groupsByCategory[categoryId][groupNumber] = {
              category_id: categoryId,
              group_number: groupNumber
            };
          }
        } catch (err) {
          console.error('Error processing match:', match, err);
        }
      });

      setCategories(Array.from(uniqueCategories).map(id => ({ id })));
      setGeneratedDraws(matchesByCategory);
      setGroups(groupsByCategory);

      // Set initial category and group if not already set
      if (!selectedCategory && uniqueCategories.size > 0) {
        const firstCategory = Array.from(uniqueCategories)[0];
        setSelectedCategory(firstCategory);
        if (matchesByCategory[firstCategory]) {
          const firstGroupNumber = Object.keys(matchesByCategory[firstCategory])[0];
          if (firstGroupNumber) {
            setSelectedGroup(String.fromCharCode(65 + parseInt(firstGroupNumber) - 1));
          }
        }
      }

      setLoading(false);
    } catch (err) {
      console.error('Error in fetchDrawsAndPlayers:', err);
      setError('Failed to load tournament data');
      setLoading(false);
    }
  };

  useEffect(() => {
    fetchDrawsAndPlayers();
  }, [tournamentId]);

  useEffect(() => {
    const fetchTournament = async () => {
      try {
        // Get tournament info from the public view
        const { data: matches, error: matchesError } = await supabase
          .from('public_round_robin_brackets')
          .select('tournament_id, tournament_name, tournament_status')
          .eq('tournament_id', tournamentId)
          .limit(1);

        if (matchesError) throw matchesError;
        if (matches && matches.length > 0) {
          setTournament({
            name: matches[0].tournament_name,
            status: matches[0].tournament_status
          });
          setDrawsSubmitted(true);
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

  const fetchStandings = async (categoryId, groupLetter) => {
    if (!categoryId || !groupLetter) return;
    
    setStandingsLoading(true);
    setStandingsError(null);
    
    try {
      // Get the group ID for the selected group letter
      const { data: groups } = await supabase
        .from('round_robin_groups')
        .select('id')
        .eq('tournament_id', tournamentId)
        .eq('category_id', categoryId)
        .eq('group_number', groupLetter.charCodeAt(0) - 64) // A=65 in ASCII, so A-64=1
        .single();

      if (!groups) {
        throw new Error('Group not found');
      }

      const { data, error } = await supabase
        .from('public_round_robin_standings')
        .select(`
          registration_id,
          first_name,
          last_name,
          partner_first_name,
          partner_last_name,
          matches_won,
          matches_lost,
          total_sets_won,
          total_sets_lost,
          games_won,
          games_lost,
          wgd,
          total_points,
          performance_index
        `)
        .eq('category_id', categoryId)
        .eq('group_id', groups.id)
        .order('performance_index', { ascending: false });

      if (error) throw error;
      
      setStandings(data || []);
    } catch (error) {
      console.error('Error fetching standings:', error);
      setStandingsError('Failed to load standings data');
    } finally {
      setStandingsLoading(false);
    }
  };

  useEffect(() => {
    if (selectedCategory && selectedGroup) {
      fetchStandings(selectedCategory, selectedGroup);
    }
  }, [selectedCategory, selectedGroup]);

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
    <div className="max-w-[1400px] mx-auto px-4 py-4 sm:py-8">
      <div className="flex justify-between items-center mb-4 sm:mb-6">
        <div>
          <h1 className="text-xl sm:text-2xl font-bold">{tournament?.name} - Status Tracker</h1>
          <div className="text-gray-600 mt-1 text-sm sm:text-base">{tournament?.status}</div>
        </div>
      </div>

      {error && (
        <div className="mb-4 p-4 bg-red-50 border border-red-200 rounded-lg">
          <div className="flex items-center text-red-800">
            <span className="text-lg mr-2">⚠️</span>
            <span>{error}</span>
          </div>
        </div>
      )}

      {loading ? (
        <div className="flex justify-center items-center h-64">
          <div className="animate-spin rounded-full h-12 w-12 border-b-2 border-blue-600"></div>
        </div>
      ) : (
        <>
          {/* Category Selection */}
          <div className="space-y-4">
            <div className="flex gap-2 sm:gap-3 overflow-x-auto p-2 sm:p-3">
              {categories.map((category) => {
                const [gender, type, ageGroup] = category.id.split('_');
                const isSelected = selectedCategory === category.id;
                const buttonWidth = 180; // Width to fit two group buttons + gap

                return (
                  <div key={category.id} className={`rounded-lg ${isSelected ? 'bg-green-50 p-2' : 'p-2'}`}>
                    <button
                      onClick={() => {
                        setSelectedCategory(category.id);
                        // Automatically select first group when category changes
                        if (generatedDraws[category.id]) {
                          const firstGroupNumber = Object.keys(generatedDraws[category.id])[0];
                          const firstGroupLetter = String.fromCharCode(65 + parseInt(firstGroupNumber) - 1);
                          setSelectedGroup(firstGroupLetter);
                        }
                      }}
                      className={`px-3 sm:px-4 py-2 rounded-lg text-xs sm:text-sm font-medium shadow-sm transition-all duration-200 w-full ${
                        isSelected
                          ? 'bg-green-50 text-green-700 ring-2 ring-green-500 ring-offset-2'
                          : 'bg-gray-100 text-gray-600 hover:bg-gray-200 border border-gray-200'
                      }`}
                      style={{ width: `${buttonWidth}px` }}
                    >
                      <span className="capitalize">{gender} {type}</span><br />
                      <span className="capitalize">{ageGroup}</span>
                    </button>
                    
                    {/* Group Selection - Show for all categories, but greyed out for unselected */}
                    {generatedDraws[category.id] && (
                      <div className="mt-2 flex flex-wrap gap-2 justify-center" style={{ width: `${buttonWidth}px` }}>
                        {Object.keys(generatedDraws[category.id]).map((groupNumber) => {
                          const groupLetter = String.fromCharCode(65 + parseInt(groupNumber) - 1);
                          const isGroupSelected = isSelected && selectedGroup === groupLetter;
                          return (
                            <button
                              key={groupNumber}
                              onClick={() => isSelected && setSelectedGroup(groupLetter)}
                              disabled={!isSelected}
                              className={`px-3 py-1 rounded text-xs font-medium transition-all duration-200 w-[84px] ${
                                isGroupSelected
                                  ? 'bg-green-600 text-white'
                                  : isSelected
                                    ? 'bg-green-100 text-green-700 hover:bg-green-200'
                                    : 'bg-gray-100 text-gray-400 cursor-default'
                              }`}
                            >
                              Group {groupLetter}
                            </button>
                          );
                        })}
                      </div>
                    )}
                  </div>
                );
              })}
            </div>
          </div>

          {selectedCategory && (
            <div className="mt-6 sm:mt-8">
              <h3 className="text-lg sm:text-xl font-semibold mb-2">
                Tournament Bracket - {
                  selectedCategory.split('_').map(word => 
                    word.charAt(0).toUpperCase() + word.slice(1)
                  ).join(' ')
                }
                {selectedGroup && ` (Group ${selectedGroup})`}
              </h3>

              {/* Remove grid layout and stack sections vertically */}
              <div className="space-y-8">
                {/* Matches Section */}
                <div>
                  {/* Match Status Legend */}
                  <div className="mb-4">
                    <h4 className="text-sm font-medium text-gray-700 mb-2">Match Status Guide:</h4>
                    <div className="flex flex-wrap gap-2">
                      <div className="min-w-[115px] h-[46px] flex items-center justify-center">
                        <div className="w-full h-[37px] border-2 border-gray-300 bg-white rounded flex items-center justify-center">
                          <span className="text-[12px]">Not Scheduled</span>
                        </div>
                      </div>
                      <div className="min-w-[115px] h-[46px] flex items-center justify-center">
                        <div className="w-full h-[37px] border-[3px] border-blue-600 bg-blue-50 rounded flex items-center justify-center">
                          <span className="text-[12px]">Scheduled</span>
                        </div>
                      </div>
                      <div className="min-w-[115px] h-[46px] flex items-center justify-center">
                        <div className="w-full h-[37px] border-[3px] border-green-500 bg-green-50 rounded flex items-center justify-center">
                          <span className="text-[12px]">Completed</span>
                        </div>
                      </div>
                      <div className="min-w-[115px] h-[46px] flex items-center justify-center">
                        <div className="w-full h-[37px] border-[3px] border-red-600 bg-red-50 rounded flex items-center justify-center">
                          <span className="text-[12px]">Overdue</span>
                        </div>
                      </div>
                      <div className="min-w-[115px] h-[46px] flex items-center justify-center">
                        <div className="w-full h-[37px] border-[4px] border-red-600 shadow-[inset_0_0_0_2px_#2563eb] bg-blue-50 rounded flex items-center justify-center">
                          <span className="text-[12px]">Scheduled & Overdue</span>
                        </div>
                      </div>
                      <div className="min-w-[115px] h-[46px] flex items-center justify-center">
                        <div className="w-full h-[37px] border-[3px] border-yellow-600 bg-yellow-50 rounded flex items-center justify-center">
                          <span className="text-[12px]">Ready to Schedule</span>
                        </div>
                      </div>
                    </div>
                  </div>

                  {/* Display matches organized by rounds */}
                  {generatedDraws[selectedCategory] && 
                    Object.entries(generatedDraws[selectedCategory]).map(([groupNumber, matches]) => {
                      const groupLetter = String.fromCharCode(65 + parseInt(groupNumber) - 1);
                      if (groupLetter !== selectedGroup) return null;

                      // Group matches by round
                      const matchesByRound = matches.reduce((acc, match) => {
                        if (!acc[match.round_number]) {
                          acc[match.round_number] = [];
                        }
                        acc[match.round_number].push(match);
                        return acc;
                      }, {});

                      const totalRounds = Object.keys(matchesByRound).length;
                      const gridStyle = {
                        display: 'grid',
                        gridTemplateColumns: `repeat(${totalRounds}, 200px)`,
                        gap: '0.125rem',
                        width: 'fit-content',
                        margin: '0 auto'
                      };

                      // Add scroll sync function
                      const handleScroll = (e) => {
                        const scrollbars = document.querySelectorAll('.sync-scroll');
                        scrollbars.forEach(scrollbar => {
                          if (scrollbar !== e.target) {
                            scrollbar.scrollLeft = e.target.scrollLeft;
                          }
                        });
                      };

                      return (
                        <div key={groupNumber} className="space-y-4">
                          {/* Top scrollbar */}
                          <div 
                            className="sync-scroll overflow-x-auto" 
                            onScroll={handleScroll} 
                            style={{ 
                              height: '16px',
                              padding: '4px 0',
                              margin: '0 4px',
                              borderRadius: '4px',
                              backgroundColor: '#f3f4f6',
                              '--scrollbar-thumb': '#d1d5db',
                              '--scrollbar-track': '#f3f4f6',
                              '--scrollbar-width': '8px',
                              scrollbarWidth: 'thin',
                              msOverflowStyle: 'none'
                            }}
                          >
                            <style>
                              {`
                                .sync-scroll::-webkit-scrollbar {
                                  height: var(--scrollbar-width);
                                  width: var(--scrollbar-width);
                                }
                                .sync-scroll::-webkit-scrollbar-track {
                                  background: var(--scrollbar-track);
                                  border-radius: 4px;
                                }
                                .sync-scroll::-webkit-scrollbar-thumb {
                                  background: var(--scrollbar-thumb);
                                  border-radius: 4px;
                                }
                                .sync-scroll::-webkit-scrollbar-thumb:hover {
                                  background: #9ca3af;
                                }
                                .sync-scroll {
                                  scrollbar-color: var(--scrollbar-thumb) var(--scrollbar-track);
                                }
                              `}
                            </style>
                            <div style={{ ...gridStyle, height: '1px' }}></div>
                          </div>

                          {/* Main content with synchronized scroll */}
                          <div 
                            className="sync-scroll overflow-x-auto"
                            onScroll={handleScroll}
                            style={{
                              borderRadius: '8px',
                              paddingBottom: '4px',
                              '--scrollbar-thumb': '#d1d5db',
                              '--scrollbar-track': '#f3f4f6',
                              '--scrollbar-width': '8px',
                              scrollbarWidth: 'thin',
                              msOverflowStyle: 'none'
                            }}
                          >
                            <div>
                              {/* Rounds header with deadlines */}
                              <div style={gridStyle}>
                                {Object.keys(matchesByRound).map((roundNumber) => (
                                  <div key={roundNumber} className="text-center px-1" style={{ width: '200px' }}>
                                    <h4 className="font-medium text-gray-900">Round {roundNumber}</h4>
                                    <p className="text-sm text-gray-500">
                                      Deadline: {matches.find(m => m.round_number === parseInt(roundNumber))?.deadline?.split('T')[0]}
                                    </p>
                                  </div>
                                ))}
                              </div>

                              {/* Matches organized by round */}
                              <div style={{ ...gridStyle, paddingBottom: '20px' }}>
                                {Object.entries(matchesByRound).map(([roundNumber, roundMatches]) => (
                                  <div key={roundNumber} className="space-y-4 px-1 flex flex-col items-center" style={{ width: '200px' }}>
                                    {roundMatches
                                      .sort((a, b) => a.match_number - b.match_number)
                                      .map((match) => (
                                        <MatchCard
                                          key={match.id}
                                          match={match}
                                          getMatchStyle={getMatchStyle}
                                        />
                                      ))}
                                  </div>
                                ))}
                              </div>
                            </div>
                          </div>
                        </div>
                      );
                    })}
                </div>

                {/* Standings Section */}
                <div>
                  <h3 className="text-xl font-semibold mb-4">Group Standings</h3>
                  <RoundRobinStandings
                    standings={standings}
                    loading={standingsLoading}
                    error={standingsError}
                  />
                </div>
              </div>
            </div>
          )}
        </>
      )}
    </div>
  );
}

export default RoundRobinBracketView; 
 
 