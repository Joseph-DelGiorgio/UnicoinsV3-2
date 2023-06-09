// src/components/MoonPay.js

//npm install axios

import React, { useState, useEffect } from 'react';
import axios from 'axios';
import './MoonPay.css';
import moonp from '/Users/josephdelgiorgio/UniCoinsV3/my-app/src/assets/moonp.jpeg'

const MOONPAY_API_KEY = ''; // Put your API key here

const MoonPay = () => {
  const [exchangeRate, setExchangeRate] = useState(null);

  useEffect(() => {
    const fetchExchangeRate = async () => {
      try {
        const response = await axios.get(
          `https://api.moonpay.io/v3/currencies/eth/price?apiKey=${MOONPAY_API_KEY}`
        );
        setExchangeRate(response.data.price);
      } catch (error) {
        console.error('Error fetching exchange rate:', error);
      }
    };

    fetchExchangeRate();
  }, []);

  return (
    <div className="moonpay">
      <img
      className="moonpay-logo"
      src={moonp}
      alt="MoonPay Logo"
    />
      {exchangeRate && (
        <p>
          Current exchange rate (ETH to USD): <strong>{exchangeRate}</strong>
        </p>
      )}
      {/* Add other UI elements and components here */}
    </div>
  );
};

export default MoonPay;
