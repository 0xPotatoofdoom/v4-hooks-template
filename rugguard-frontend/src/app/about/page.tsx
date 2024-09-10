import React from 'react';

const About: React.FC = () => {
  return (
    <div className="max-w-md mx-auto p-4">
      <h2 className="text-2xl font-bold mb-4">About RugGuard</h2>
      <p className="mb-2 text-gray-800" >
        RugGuard is a security-focused solution designed to protect liquidity providers in DeFi projects.
        Our goal is to prevent rug pulls and ensure a safe trading environment on Uniswap V4.
      </p>
      <p className="mb-2 text-gray-800">
        With features like real-time liquidity monitoring, intelligent transaction throttling, and dynamic security thresholds,
        RugGuard enhances the security of your investments.
      </p>
      <p className="mb-2 text-gray-800">
        Join us in making DeFi safer for everyone!
      </p>
      <p className="mb-2 text-gray-800">
        Code for this project can be found at <a href="https://github.com/0xPotatoofdoom/v4-hooks-template/tree/rugguard" target="_blank" rel="noopener noreferrer">https://github.com/0xPotatoofdoom/v4-hooks-template/tree/rugguard</a>
      </p>
      <p className="mb-2 text-gray-800">
        Built by <a href="https://twitter.com/0xPotatoofdoom" target="_blank" rel="noopener noreferrer">0xPotatoofdoom</a> and <a href="https://twitter.com/rax090909" target="_blank" rel="noopener noreferrer">rax090909</a>
      </p>
      <p className="mb-2 text-gray-800">
        This project is not affiliated with Uniswap but uses Uniswap V4 hooks and was made as part of <a href="https://atrium.academy/uniswap" target="_blank" rel="noopener noreferrer">Atrium Academy</a>'s 2nd cohort that was funded by grants from <a href="https://uniswap.org/grants/" target="_blank" rel="noopener noreferrer">Uniswap Foundation</a>.
      </p>
    </div>
  );
};

export default About;