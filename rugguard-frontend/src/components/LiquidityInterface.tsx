'use client';

import React, { useState } from 'react';

const LiquidityInterface: React.FC = () => {
  const [amount, setAmount] = useState('');
  const [operation, setOperation] = useState<'add' | 'remove'>('add');

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    // Implement liquidity addition/removal logic here
    console.log(`${operation} liquidity: ${amount}`);
  };

  return (
    <div className="max-w-md mx-auto">
      <h2 className="text-2xl font-bold mb-4">Manage Liquidity</h2>
      <form onSubmit={handleSubmit} className="space-y-4">
        <div>
          <label className="block text-sm font-medium text-gray-700">Operation</label>
          <select
            value={operation}
            onChange={(e) => setOperation(e.target.value as 'add' | 'remove')}
            className="mt-1 block w-full pl-3 pr-10 py-2 text-base border-gray-300 focus:outline-none focus:ring-indigo-500 focus:border-indigo-500 sm:text-sm rounded-md"
          >
            <option value="add">Add Liquidity</option>
            <option value="remove">Remove Liquidity</option>
          </select>
        </div>
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
        <button
          type="submit"
          className="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
        >
          {operation === 'add' ? 'Add Liquidity' : 'Remove Liquidity'}
        </button>
      </form>
    </div>
  );
};

export default LiquidityInterface;