'use client'; // Make this a Client Component

import React, { useState } from 'react';

const StakingPage: React.FC = () => {
  const [amount, setAmount] = useState('');
  const [action, setAction] = useState<'stake' | 'unstake'>('stake');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    // Implement minting, staking, or unstaking logic here
    console.log(`${action} amount: ${amount}`);
  };

  return (
    <div className="max-w-7xl mx-auto p-4">
      <h2 className="text-2xl font-bold mb-4 text-gray-800">Earn & Staking</h2>
      <p className="mb-4 text-gray-800">
        Welcome to the staking platform! Here you can mint, stake, and unstake your tokens.
        Learn about our tokenomics below.
      </p>

      <h3 className="text-xl font-semibold mb-2 text-gray-800">Tokenomics</h3>
      <p className="mb-4 text-gray-800">
        Our tokenomics are designed to ensure sustainability and growth. 
        - Total Supply: 1,000,000 Tokens
        - Staking Rewards: 10% APY
        - Minting Fee: 2%
      </p>

      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700">Amount</label>
          <input
            type="number"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            className="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
            placeholder="Enter amount"
          />
        </div>
        <div>
          <label className="block text-sm font-medium text-gray-700">Action</label>
          <select
            value={action}
            onChange={(e) => setAction(e.target.value as 'stake' | 'unstake')}
            className="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
          >
            <option value="stake">Stake</option>
            <option value="unstake">Unstake</option>
          </select>
        </div>
        <button
          type="submit"
          className="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
        >
          {action === 'stake' ? 'Stake Tokens' : 'Unstake Tokens'}
        </button>
      </form>
    </div>
  );
};

export default StakingPage;