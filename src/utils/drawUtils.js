import { differenceInDays, addDays } from 'date-fns';

/**
 * Calculate the appropriate bracket size (next power of 2) for the number of players
 * @param {number} playerCount - Total number of players
 * @returns {number} - Bracket size (8, 16, 32, etc.)
 */
export const calculateBracketSize = (playerCount) => {
  let size = 2;
  while (size < playerCount) {
    size *= 2;
  }
  return size;
};

/**
 * Calculate positions for seeded players and their byes in the bracket
 * @param {number} bracketSize - Size of the bracket (8, 16, 32, etc.)
 * @param {number} seedCount - Number of seeds
 * @param {number} byeCount - Number of byes to distribute
 * @returns {{seedPositions: number[], byePositions: number[]}} - Arrays of positions for seeds and byes
 */
export const calculateSeedAndByePositions = (bracketSize, seedCount, byeCount) => {
  const seedPositions = [];
  const byePositions = [];
  
  // Standard seed positions in a draw
  if (seedCount >= 1) seedPositions[0] = 0;                          // 1st seed: top of first quarter
  if (seedCount >= 2) seedPositions[1] = bracketSize - 1;           // 2nd seed: bottom of fourth quarter
  if (seedCount >= 3) seedPositions[2] = Math.floor(bracketSize / 4);     // 3rd seed: top of second quarter
  if (seedCount >= 4) seedPositions[3] = Math.floor(bracketSize / 2);     // 4th seed: top of third quarter
  
  // Additional seeds follow similar pattern
  if (seedCount >= 5) {
    seedPositions[4] = Math.floor(bracketSize * 1/8);
    seedPositions[5] = Math.floor(bracketSize * 7/8);
    seedPositions[6] = Math.floor(bracketSize * 5/8);
    seedPositions[7] = Math.floor(bracketSize * 3/8);
  }
  
  // Assign byes to seeded players first
  const byesToSeeds = Math.min(byeCount, seedCount);
  for (let i = 0; i < byesToSeeds; i++) {
    // Bye position is the next position after the seed
    const seedPos = seedPositions[i];
    const byePos = (seedPos % 2 === 0) ? seedPos + 1 : seedPos - 1;
    byePositions.push(byePos);
  }
  
  // If there are remaining byes, distribute them evenly in remaining spots
  if (byeCount > byesToSeeds) {
    const remainingByes = byeCount - byesToSeeds;
    const usedPositions = new Set([...seedPositions, ...byePositions]);
    
    // Create array of all possible positions and filter out used ones
    const availablePositions = Array.from({length: bracketSize}, (_, i) => i)
      .filter(pos => !usedPositions.has(pos));
    
    // Calculate spacing for remaining byes
    const spacing = Math.floor(availablePositions.length / remainingByes);
    
    // Distribute remaining byes
    for (let i = 0; i < remainingByes; i++) {
      const pos = availablePositions[i * spacing];
      byePositions.push(pos);
    }
  }
  
  return { seedPositions, byePositions };
};

/**
 * Calculate round deadlines using Linear Distribution
 */
export const calculateLinearDeadlines = (startDate, endDate, numRounds) => {
  const totalDays = differenceInDays(new Date(endDate), new Date(startDate));
  const daysPerRound = totalDays / numRounds;
  
  return Array.from({length: numRounds}, (_, i) => {
    return addDays(new Date(startDate), Math.ceil(daysPerRound * (i + 1)));
  });
};

/**
 * Calculate round deadlines using Match-Based Progressive Weighting
 * Weights slightly favor early rounds but maintain substantial time for later rounds
 */
export const calculateProgressiveDeadlines = (startDate, endDate, numRounds) => {
  const totalDays = differenceInDays(new Date(endDate), new Date(startDate));
  
  // Revised weights with more balanced distribution
  const weights = {
    3: [0.33, 0.33, 0.34],                    // 8 players
    4: [0.28, 0.24, 0.24, 0.24],              // 16 players
    5: [0.25, 0.20, 0.20, 0.18, 0.17],        // 32 players
    6: [0.22, 0.18, 0.16, 0.16, 0.14, 0.14],  // 64 players
    7: [0.20, 0.16, 0.14, 0.14, 0.13, 0.12, 0.11] // 128 players
  };

  if (!weights[numRounds]) {
    return calculateLinearDeadlines(startDate, endDate, numRounds);
  }

  let currentDate = new Date(startDate);
  return weights[numRounds].map(weight => {
    const roundDays = Math.ceil(totalDays * weight);
    currentDate = addDays(currentDate, roundDays);
    return currentDate;
  });
};

/**
 * Calculate round deadlines using Balanced Distribution with Match Count Consideration
 * This method considers both the number of matches and the importance of later rounds
 */
export const calculateBalancedDeadlines = (startDate, endDate, numRounds) => {
  const totalDays = differenceInDays(new Date(endDate), new Date(startDate));
  
  // Calculate matches per round and total matches
  const matchesPerRound = Array.from({length: numRounds}, (_, i) => 
    Math.pow(2, numRounds - i - 1)
  );
  const totalMatches = matchesPerRound.reduce((sum, matches) => sum + matches, 0);
  
  // Calculate base weight for each match
  const baseMatchWeight = 1 / totalMatches;
  
  // Apply round importance multiplier (increases for later rounds)
  const weights = matchesPerRound.map((matches, index) => {
    const roundImportance = 1 + (index / (numRounds - 1)) * 0.5; // 1.0 to 1.5 multiplier
    return (matches * baseMatchWeight * roundImportance);
  });
  
  // Normalize weights to sum to 1
  const weightSum = weights.reduce((sum, weight) => sum + weight, 0);
  const normalizedWeights = weights.map(weight => weight / weightSum);
  
  // Calculate deadlines
  let currentDate = new Date(startDate);
  return normalizedWeights.map(weight => {
    const roundDays = Math.ceil(totalDays * weight);
    currentDate = addDays(currentDate, roundDays);
    return currentDate;
  });
};

/**
 * Generate the tournament draw
 * @param {Object[]} players - Array of player objects
 * @param {Set} seededPlayers - Set of seeded player IDs
 * @param {number} bracketSize - Size of the bracket
 * @returns {Object[]} - Array of matches with player assignments
 */
export const generateDraw = (players, seededPlayers, bracketSize) => {
  // Create array of all positions
  const positions = Array(bracketSize).fill(null);
  
  // Calculate number of byes needed
  const byeCount = bracketSize - players.length;
  
  // Get seed and bye positions
  const { seedPositions, byePositions } = calculateSeedAndByePositions(
    bracketSize, 
    seededPlayers.size,
    byeCount
  );
  
  // Place seeded players
  const seededPlayersList = Array.from(seededPlayers);
  seedPositions.forEach((pos, index) => {
    if (index < seededPlayersList.length) {
      const seededPlayer = players.find(p => p.id === seededPlayersList[index]);
      if (seededPlayer) {
        positions[pos] = {
          ...seededPlayer,
          seedNumber: index + 1,
          isSeeded: true
        };
      }
    }
  });
  
  // Place byes
  byePositions.forEach(pos => {
    positions[pos] = 'bye';
  });
  
  // Get remaining players
  const unseededPlayers = players
    .filter(p => !seededPlayers.has(p.id))
    .map(p => ({ ...p, isSeeded: false }));
  
  // Get empty positions for remaining players
  const emptyPositions = positions
    .map((p, index) => p === null ? index : -1)
    .filter(pos => pos !== -1);
  
  // Shuffle empty positions
  for (let i = emptyPositions.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [emptyPositions[i], emptyPositions[j]] = [emptyPositions[j], emptyPositions[i]];
  }
  
  // Place unseeded players
  unseededPlayers.forEach((player, index) => {
    if (index < emptyPositions.length) {
      positions[emptyPositions[index]] = player;
    }
  });
  
  // Convert positions array to matches array
  const matches = [];
  for (let i = 0; i < bracketSize; i += 2) {
    matches.push({
      player1: positions[i],
      player2: positions[i + 1],
      round: 1,
      matchNumber: Math.floor(i/2) + 1
    });
  }
  
  return matches;
};

/**
 * Generate the full tournament bracket structure with deadlines
 * @param {Object[]} firstRoundMatches - Array of first round matches
 * @param {number} bracketSize - Size of the bracket
 * @param {string} startDate - Start date of the tournament
 * @param {string} endDate - End date of the tournament
 * @param {boolean} useProgressiveDeadlines - Whether to use progressive deadlines
 * @returns {Object[]} - Full bracket structure with all rounds and deadlines
 */
export const generateBracketStructure = (firstRoundMatches, bracketSize, startDate, endDate, useProgressiveDeadlines = true) => {
  const rounds = Math.log2(bracketSize);
  const bracket = [];
  
  // Calculate deadlines
  const deadlines = useProgressiveDeadlines 
    ? calculateProgressiveDeadlines(startDate, endDate, rounds)
    : calculateLinearDeadlines(startDate, endDate, rounds);
  
  // Add first round with deadline
  bracket.push(firstRoundMatches.map(match => ({
    ...match,
    deadline: deadlines[0]
  })));
  
  // Generate subsequent rounds with deadlines
  for (let round = 2; round <= rounds; round++) {
    const matchesInRound = bracketSize / Math.pow(2, round);
    const roundMatches = [];
    
    for (let i = 0; i < matchesInRound; i++) {
      roundMatches.push({
        player1: null,
        player2: null,
        round: round,
        matchNumber: i + 1,
        deadline: deadlines[round - 1]
      });
    }
    
    bracket.push(roundMatches);
  }
  
  return bracket;
};

const getPlayerName = (player) => {
  if (player === 'bye') return 'BYE';
  if (!player || !player.registrationId) return 'TBD';
  const info = playerInfo[player.registrationId];
  if (!info) return 'TBD';
  // Adjust for your playerInfo structure
  return `${info.first_name || info.firstName} ${info.last_name || info.lastName}`;
}; 