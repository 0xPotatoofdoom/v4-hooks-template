'use client'; // Add this line to make the component a Client Component

import React from 'react';

const PoolTxQueue: React.FC = () => {
  // Mock data - replace with actual data from your contract
  const pendingTransactions = [
    { id: 1, pool: 'ETH/USDC', amount: '1,000', status: 'Pending' },
    { id: 2, pool: 'BTC/ETH', amount: '0.5', status: 'Pending' },
  ];

  const handleApprove = (id: number) => {
    // Implement approval logic here
    console.log(`Approved transaction with ID: ${id}`);
  };
  
  const handleReject = (id: number) => {
    // Implement rejection logic here
    console.log(`Rejected transaction with ID: ${id}`);
  };

  return (
    <div className="max-w-7xl mx-auto p-4">
      <h2 className="text-2xl font-bold mb-4">Pool TX Queue</h2>
      <div className="overflow-x-auto">
        <table className="min-w-full divide-y divide-gray-200">
          <thead className="bg-gray-50">
            <tr>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-800 uppercase tracking-wider">Pool</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-800 uppercase tracking-wider">Amount</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-800 uppercase tracking-wider">Status</th>
              <th className="px-6 py-3 text-left text-xs font-medium text-gray-800 uppercase tracking-wider">Action</th>
            </tr>
          </thead>
          <tbody className="bg-white divide-y divide-gray-200">
            {pendingTransactions.map((tx) => (
              <tr key={tx.id}>
                <td className="px-6 py-4 whitespace-nowrap text-gray-800">{tx.pool}</td>
                <td className="px-6 py-4 whitespace-nowrap text-gray-800">{tx.amount}</td>
                <td className="px-6 py-4 whitespace-nowrap text-gray-800">{tx.status}</td>
                <td className="px-6 py-4 whitespace-nowrap">
                <button
                    onClick={() => handleApprove(tx.id)}
                    className="bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700"
                  >
                    Approve
                  </button>
                  &nbsp;
                  <button
                    onClick={() => handleReject(tx.id)}
                    className="bg-red-600 text-white px-4 py-2 rounded hover:bg-red-700"
                  >
                    Reject
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

export default PoolTxQueue;