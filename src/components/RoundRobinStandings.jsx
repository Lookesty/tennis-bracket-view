import React from 'react';

const RoundRobinStandings = ({ standings, loading, error }) => {
  if (loading) {
    return (
      <div className="mt-8 p-4 bg-white rounded-lg shadow">
        <div className="animate-pulse flex space-x-4">
          <div className="flex-1 space-y-4 py-1">
            <div className="h-4 bg-gray-200 rounded w-3/4"></div>
            <div className="space-y-2">
              <div className="h-4 bg-gray-200 rounded"></div>
              <div className="h-4 bg-gray-200 rounded"></div>
              <div className="h-4 bg-gray-200 rounded"></div>
            </div>
          </div>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="mt-8 p-4 bg-red-50 border border-red-200 rounded-lg">
        <div className="text-red-700">{error}</div>
      </div>
    );
  }

  if (!standings || standings.length === 0) {
    return (
      <div className="mt-8 p-4 bg-gray-50 border border-gray-200 rounded-lg">
        <div className="text-gray-500 text-center">No standings data available yet</div>
      </div>
    );
  }

  return (
    <div className="mt-8">
      <h3 className="text-xl font-semibold mb-4">Standings</h3>
      <div className="overflow-x-auto">
        <table className="min-w-full bg-white rounded-lg shadow">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Player Name</th>
              <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider" title="Matches Played">MP</th>
              <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider" title="Matches Won">W</th>
              <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider" title="Matches Lost">L</th>
              <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider" title="Sets Won">SW</th>
              <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider" title="Sets Lost">SL</th>
              <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider" title="Games Won">GW</th>
              <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider" title="Games Lost">GL</th>
              <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider" title="Walkover Games Difference">WGD</th>
              <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider">Points</th>
              <th className="px-4 py-3 text-center text-xs font-medium text-gray-500 uppercase tracking-wider" title="Performance Index">PI</th>
            </tr>
          </thead>
          <tbody className="divide-y divide-gray-200">
            {standings.map((player, index) => (
              <tr key={player.registration_id} className={index % 2 === 0 ? 'bg-white' : 'bg-gray-50'}>
                <td className="px-4 py-2 whitespace-nowrap text-sm font-medium text-gray-900">
                  {`${player.first_name} ${player.last_name}`}
                </td>
                <td className="px-4 py-2 whitespace-nowrap text-sm text-center text-gray-500">
                  {(player.matches_won || 0) + (player.matches_lost || 0)}
                </td>
                <td className="px-4 py-2 whitespace-nowrap text-sm text-center text-gray-500">{player.matches_won || 0}</td>
                <td className="px-4 py-2 whitespace-nowrap text-sm text-center text-gray-500">{player.matches_lost || 0}</td>
                <td className="px-4 py-2 whitespace-nowrap text-sm text-center text-gray-500">{player.total_sets_won || 0}</td>
                <td className="px-4 py-2 whitespace-nowrap text-sm text-center text-gray-500">{player.total_sets_lost || 0}</td>
                <td className="px-4 py-2 whitespace-nowrap text-sm text-center text-gray-500">{player.games_won}</td>
                <td className="px-4 py-2 whitespace-nowrap text-sm text-center text-gray-500">{player.games_lost}</td>
                <td className="px-4 py-2 whitespace-nowrap text-sm text-center text-gray-500">{player.wgd}</td>
                <td className="px-4 py-2 whitespace-nowrap text-sm text-center text-gray-500">{player.total_points}</td>
                <td className="px-4 py-2 whitespace-nowrap text-sm text-center font-medium text-gray-900">
                  {(player.performance_index || 0).toFixed(2)}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default RoundRobinStandings; 