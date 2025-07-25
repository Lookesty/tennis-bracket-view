/**
 * Generates groups for a round robin tournament
 * @param {Object[]} players - Array of player objects
 * @param {number} groupSize - Number of players per group (default 4)
 * @returns {Object[]} Array of groups with players
 */
export const generateGroups = (players, groupSize = 4) => {
  // Shuffle players randomly
  const shuffledPlayers = [...players].sort(() => Math.random() - 0.5);
  const groups = [];
  
  // Create groups of specified size
  for (let i = 0; i < shuffledPlayers.length; i += groupSize) {
    groups.push(shuffledPlayers.slice(i, i + groupSize));
  }
  
  return groups;
};

/**
 * Generates matches for a round robin group
 * @param {Object[]} players - Array of players in the group
 * @param {number} numberOfRounds - Number of rounds to generate (defaults to maximum possible)
 * @returns {Object[]} Array of matches with player assignments and round numbers
 */
export const generateGroupMatches = (players, numberOfRounds = null) => {
  const matches = [];
  const n = players.length;
  
  // If odd number of players, add a "bye" player
  const isOdd = n % 2 === 1;
  const totalPlayers = isOdd ? n + 1 : n;
  const maxRounds = totalPlayers - 1;
  const matchesPerRound = Math.floor(totalPlayers / 2);
  
  // Determine how many rounds to generate
  const roundsToGenerate = numberOfRounds ? Math.min(numberOfRounds, maxRounds) : maxRounds;
  
  // Create array of player indices (including bye if needed)
  const indices = Array.from({ length: totalPlayers }, (_, i) => i < n ? players[i] : 'bye');
  
  // Generate matches for each round using circle method
  for (let round = 0; round < roundsToGenerate; round++) {
    for (let match = 0; match < matchesPerRound; match++) {
      const player1Idx = match;
      const player2Idx = totalPlayers - 1 - match;
      
      // Skip matches involving "bye" player
      if (indices[player1Idx] !== 'bye' && indices[player2Idx] !== 'bye') {
        matches.push({
          round: round + 1,
          player1: indices[player1Idx],
          player2: indices[player2Idx],
          status: 'pending'
        });
      }
    }
    
    // Rotate players (keep first player fixed)
    const lastPlayer = indices[totalPlayers - 1];
    for (let i = totalPlayers - 1; i > 1; i--) {
      indices[i] = indices[i - 1];
    }
    indices[1] = lastPlayer;
  }
  
  return matches;
};

/**
 * Calculate standings for a round robin group
 * @param {Object[]} matches - Array of completed matches in the group
 * @param {Object[]} players - Array of players in the group
 * @returns {Object[]} Array of player standings with points and statistics
 */
export const calculateStandings = (matches, players) => {
  const standings = players.map(player => ({
    player,
    matches: 0,
    wins: 0,
    losses: 0,
    points: 0,
    setsWon: 0,
    setsLost: 0,
    gamesWon: 0,
    gamesLost: 0
  }));

  matches.forEach(match => {
    if (match.status !== 'completed' && match.status !== 'walkover') return;

    const player1Standing = standings.find(s => s.player.id === match.player1.id);
    const player2Standing = standings.find(s => s.player.id === match.player2.id);

    if (!player1Standing || !player2Standing) return;

    player1Standing.matches++;
    player2Standing.matches++;

    if (match.status === 'walkover') {
      if (match.winner === match.player1.id) {
        player1Standing.wins++;
        player1Standing.points += 2;
        player2Standing.losses++;
      } else {
        player2Standing.wins++;
        player2Standing.points += 2;
        player1Standing.losses++;
      }
      return;
    }

    // Process completed match scores
    let player1Sets = 0;
    let player2Sets = 0;
    let player1Games = 0;
    let player2Games = 0;

    match.score.forEach(set => {
      if (set.player1Score > set.player2Score) {
        player1Sets++;
      } else {
        player2Sets++;
      }
      player1Games += set.player1Score;
      player2Games += set.player2Score;
    });

    player1Standing.setsWon += player1Sets;
    player1Standing.setsLost += player2Sets;
    player1Standing.gamesWon += player1Games;
    player1Standing.gamesLost += player2Games;

    player2Standing.setsWon += player2Sets;
    player2Standing.setsLost += player1Sets;
    player2Standing.gamesWon += player2Games;
    player2Standing.gamesLost += player1Games;

    if (player1Sets > player2Sets) {
      player1Standing.wins++;
      player1Standing.points += 2;
      player2Standing.losses++;
    } else {
      player2Standing.wins++;
      player2Standing.points += 2;
      player1Standing.losses++;
    }
  });

  // Sort standings by points, then head-to-head, then set difference, then game difference
  return standings.sort((a, b) => {
    if (b.points !== a.points) return b.points - a.points;
    const setDiffA = a.setsWon - a.setsLost;
    const setDiffB = b.setsWon - b.setsLost;
    if (setDiffB !== setDiffA) return setDiffB - setDiffA;
    const gameDiffA = a.gamesWon - a.gamesLost;
    const gameDiffB = b.gamesWon - b.gamesLost;
    return gameDiffB - gameDiffA;
  });
};

/**
 * Calculate round deadlines for a round robin group using linear distribution
 * @param {string} startDate - Tournament start date
 * @param {string} endDate - Tournament end date
 * @param {number} numberOfPlayers - Number of players in the group
 * @returns {string[]} Array of deadline dates in ISO format
 */
export const calculateRoundRobinDeadlines = (startDate, endDate, numberOfPlayers) => {
  // In round robin, number of rounds is (n-1) where n is number of players
  const numberOfRounds = numberOfPlayers - 1;
  
  // Convert dates to timestamps
  const start = new Date(startDate).getTime();
  const end = new Date(endDate).getTime();
  
  // Calculate time per round (linear distribution)
  const timePerRound = (end - start) / numberOfRounds;
  
  // Generate deadlines array
  const deadlines = [];
  for (let i = 0; i < numberOfRounds; i++) {
    const deadlineTime = start + (timePerRound * (i + 1));
    const deadlineDate = new Date(deadlineTime);
    // Format date as ISO string and take only the date part
    deadlines.push(deadlineDate.toISOString().split('T')[0]);
  }
  
  return deadlines;
}; 