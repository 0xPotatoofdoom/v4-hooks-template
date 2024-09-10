'use client';

import React from 'react';

const PoolOverview: React.FC = () => {
  // Mock data - replace with actual data from your contract
  const pools = [
    { id: 1, name: 'ETH/USDC', riskScore: 20, liquidity: '1,000,000' },
    { id: 2, name: 'BTC/ETH', riskScore: 35, liquidity: '500,000' },
  ];

  return (
    <div>
      <h2 className="text-2xl font-bold mb-4">Pool Overview</h2>
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Pool</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Risk Score</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider">Liquidity</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {pools.map((pool) => (
              <tr key={pool.id}>
                <td className="px-6 py-4 whitespace-nowrap">{pool.name}</td>
                <td className="px-6 py-4 whitespace-nowrap">{pool.riskScore}</td>
                <td className="px-6 py-4 whitespace-nowrap">${pool.liquidity}</td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default PoolOverview;