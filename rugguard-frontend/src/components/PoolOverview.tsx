'use client';

import React from 'react';

const PoolOverview: React.FC = () => {
  // Mock data - replace with actual data from your contract
  const pools = [
    { id: 1, name: 'ETH/USDC', riskScore: 20, liquidity: '1,000,000' },
    { id: 2, name: 'BTC/ETH', riskScore: 35, liquidity: '500,000' },
  ];

  const handleView = (id: number) => {
    // Implement view logic here
    console.log(`Viewing pool with ID: ${id}`);
  };

  const handleManage = (id: number) => {
    // Implement manage logic here
    console.log(`Managing pool with ID: ${id}`);
  };

  return (
    <div>
      <h2 className="text-2xl font-bold mb-4">Pool Overview</h2>
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-800 uppercase tracking-wider">Pool</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-800 uppercase tracking-wider">Risk Score</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-800 uppercase tracking-wider">Liquidity</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-800 uppercase tracking-wider">Actions</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {pools.map((pool) => (
              <tr key={pool.id}>
                <td className="px-6 py-4 whitespace-nowrap text-gray-800">{pool.name}</td>
                <td className="px-6 py-4 whitespace-nowrap text-gray-800">{pool.riskScore}</td>
                <td className="px-6 py-4 whitespace-nowrap text-gray-800">${pool.liquidity}</td>
                <td className="px-6 py-4 whitespace-nowrap">
                  <button
                    onClick={() => handleView(pool.id)}
                    className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700 mr-2"
                  >
                    View
                  </button>
                  <button
                    onClick={() => handleManage(pool.id)}
                    className="bg-green-600 text-white px-4 py-2 rounded hover:bg-green-700"
                  >
                    Manage
                  </button>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
};

export default PoolOverview;