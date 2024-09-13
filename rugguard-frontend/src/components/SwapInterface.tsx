'use client';

import React, { useState } from 'react';

const SwapInterface: React.FC = () => {
  const [fromAmount, setFromAmount] = useState('');
  const [toAmount, setToAmount] = useState('');
  const [fromToken, setFromToken] = useState('ETH');
  const [toToken, setToToken] = useState('USDC');

  const handleSwap = (e: React.FormEvent) => {
    e.preventDefault();
    // Implement swap logic here
    console.log(`Swap ${fromAmount} ${fromToken} for ${toAmount} ${toToken}`);
  };

  return (
    <div className="max-w-md mx-auto">
      <h2 className="text-2xl font-bold mb-4">Swap Tokens</h2>
      <form onSubmit={handleSwap} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700">From</label>
          <div className="mt-1 flex rounded-md shadow-sm">
            <input
              type="number"
              value={fromAmount}
              onChange={(e) => setFromAmount(e.target.value)}
              className="flex-1 min-w-0 block w-full px-3 py-2 rounded-none rounded-l-md focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm border-gray-300"
              placeholder="Amount"
            />
            <select
              value={fromToken}
              onChange={(e) => setFromToken(e.target.value)}
              className="inline-flex items-center px-3 rounded-r-md border border-l-0 border-gray-300 bg-gray-50 text-gray-500 sm:text-sm"
            >
              <option>ETH</option>
              <option>USDC</option>
            </select>
          </div>
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700">To</label>
          <div className="mt-1 flex rounded-md shadow-sm">
            <input
              type="number"
              value={toAmount}
              onChange={(e) => setToAmount(e.target.value)}
              className="flex-1 min-w-0 block w-full px-3 py-2 rounded-none rounded-l-md focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm border-gray-300"
              placeholder="Amount"
            />
            <select
              value={toToken}
              onChange={(e) => setToToken(e.target.value)}
              className="inline-flex items-center px-3 rounded-r-md border border-l-0 border-gray-300 bg-gray-50 text-gray-500 sm:text-sm"
            >
              <option>USDC</option>
              <option>ETH</option>
            </select>
          </div>
        </div>
        <button
          type="submit"
          className="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
        >
          Swap
        </button>
      </form>
    </div>
  );
};

export default SwapInterface;