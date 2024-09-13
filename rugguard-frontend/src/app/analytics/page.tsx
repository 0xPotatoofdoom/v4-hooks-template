'use client'; // Make this a Client Component

import React, { useEffect, useState } from 'react';

const AnalyticsPage: React.FC = () => {
  const [poolsData, setPoolsData] = useState<{ id: number; name: string; riskScore: number; liquidity: number; }[]>([]); // Specify the type for state
  const [totalLiquidity, setTotalLiquidity] = useState(0);
  const [averageRiskScore, setAverageRiskScore] = useState(0);

  useEffect(() => {
    // Fetch pool data from your API or smart contract
    const fetchPoolsData = async () => {
      // Mock data - replace with actual data fetching logic
      const mockData = [
        { id: 1, name: 'ETH/USDT', riskScore: 20, liquidity: 100000 },
        { id: 2, name: 'BTC/ETH', riskScore: 35, liquidity: 500000 },
      ];
      setPoolsData(mockData); // This will now work correctly

      // Calculate total liquidity and average risk score
      const total = mockData.reduce((acc, pool) => acc + pool.liquidity, 0);
      const averageRisk = mockData.reduce((acc, pool) => acc + pool.riskScore, 0) / mockData.length;

      setTotalLiquidity(total);
      setAverageRiskScore(averageRisk);
    };

    fetchPoolsData();
  }, []);

  return (
    <div className="max-w-7xl mx-auto p-4">
      <h2 className="text-2xl font-bold mb-4">Analytics Dashboard</h2>
      <div className="mb-4">
        <h3 className="text-xl font-semibold">Key Metrics</h3>
        <p>Total Pools: {poolsData.length}</p>
        <p>Total Liquidity: ${totalLiquidity.toLocaleString()}</p>
        <p>Average Risk Score: {averageRiskScore.toFixed(2)}</p>
      </div>
      <h3 className="text-xl font-semibold mb-2">Pools Overview</h3>
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-800 uppercase tracking-wider">Pool</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-800 uppercase tracking-wider">Risk Score</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-800 uppercase tracking-wider">Liquidity</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {poolsData.map((pool) => (
              <tr key={pool.id}>
                <td className="px-6 py-4 whitespace-nowrap text-gray-800">{pool.name}</td>
                <td className="px-6 py-4 whitespace-nowrap text-gray-800">{pool.riskScore}</td>
                <td className="px-6 py-4 whitespace-nowrap text-gray-800">${pool.liquidity.toLocaleString()}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default AnalyticsPage;