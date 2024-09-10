import React from 'react';
import Link from 'next/link';

const Layout: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  return (
    <div className="min-h-screen bg-gray-100">
      <nav className="bg-white shadow-md">
        <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
          <div className="flex justify-between h-16">
            <div className="flex">
              <Link href="/" className="flex-shrink-0 flex items-center text-gray-800">
                RugGuard
              </Link>
              <div className="ml-6 flex space-x-8">
                <Link href="/" className="text-gray-900 inline-flex items-center px-1 pt-1 border-b-2 border-transparent">
                  Pools
                </Link>
                <Link href="/liquidity" className="text-gray-900 inline-flex items-center px-1 pt-1 border-b-2 border-transparent">
                  Liquidity
                </Link>
                <Link href="/swap" className="text-gray-900 inline-flex items-center px-1 pt-1 border-b-2 border-transparent">
                  Swap
                </Link>
                <Link href="/about" className="text-gray-900 inline-flex items-center px-1 pt-1 border-b-2 border-transparent">
                  About
                </Link>
              </div>
            </div>
          </div>
        </div>
      </nav>
      <main className="max-w-7xl mx-auto py-6 sm:px-6 lg:px-8">
        {children}
      </main>
    </div>
  );
};

export default Layout;