import React from 'react';

const About: React.FC = () => {
  return (
    <div className="max-w-md mx-auto p-4">
      <h2 className="text-2xl font-bold mb-4">About RugGuard</h2>
      <p className="mb-2">
        RugGuard is a security-focused solution designed to protect liquidity providers in DeFi projects.
        Our goal is to prevent rug pulls and ensure a safe trading environment on Uniswap V4.
      </p>
      <p className="mb-2">
        With features like real-time liquidity monitoring, intelligent transaction throttling, and dynamic security thresholds,
        RugGuard enhances the security of your investments.
      </p>
      <p>
        Join us in making DeFi safer for everyone!
      </p>
      <p>
        Code for this project can be found at <a href="https://github.com/0xPotatoofdoom/v4-hooks-template/tree/rugguard" target="_blank" rel="noopener noreferrer">https://github.com/0xPotatoofdoom/v4-hooks-template/tree/rugguard</a>
        <br />
        This project is not affiliated with Uniswap but uses Uniswap V4 hooks and was made as part of Atrium Academy's 2nd cohort that was funded by grants from Uniswap Foundation.
      </p>
    </div>
  );
};

export default About;