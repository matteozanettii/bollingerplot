# FSDA Bollinger Analysis Tool

A specialized MATLAB utility for technical financial analysis, designed to act as a seamless visualization extension for the **FSDA (Flexible Statistics and Data Analysis) Toolbox**. 

## Overview
`bollingerplot.m` processes financial data fetched via the FSDA ecosystem to provide automated technical overlays. It is optimized for the `timetable` structures returned by the latest FSDA financial functions.

### Key Features
- **FSDA Native:** Direct support for `getYahoo` output structures.
- **Advanced Technicals:** Automated calculation of 20-period SMA and volatility bands at $\pm 2\sigma$.
- **Trend Intelligence:** Segment-based color-coding (Green/Red) for immediate price-action recognition.
- **Global Alignment:** Built-in UTC normalization for cross-market synchronization.

## Dependencies
This tool requires the **FSDA Toolbox** to be installed:
- **Official FSDA Documentation:** [https://rosa.unipr.it/FSDA/](https://rosa.unipr.it/FSDA/)
- **Financial Functions:** [FSDA Utility Functions](https://rosa.unipr.it/FSDA/function-cate.html#UTI)

## Quick Start
```matlab
% 1. Fetch data using FSDA
data = getYahoo({'AAPL', 'TSLA', 'BTC-USD'});

% 2. Run Bollinger Analysis
results = bollingerplot(data);

% 3. Review Summary
disp(results.summary);
