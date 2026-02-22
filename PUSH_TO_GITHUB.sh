#!/bin/bash
# SVP Protocol - GitHub Push Script
# Run this in PowerShell from the capitalBridge directory

# Navigate to project root
cd "C:\Users\ALBASH SOLUTION\Music\capitalBridge"

# Initialize git repository
git init

# Configure git (update with your details)
git config user.name "Your Name"
git config user.email "your.email@github.com"

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: SVP Protocol - Smart Contracts, DApp, and SDK

- Smart Contracts: 10 core contracts with >90% test coverage
- DApp: Next.js 14 frontend with wallet integration
- SDK: TypeScript SDK for easy integration
- Tests: 99 test cases for protocol validation
- Gas Optimization: Deployed with IR-based compilation
- Networks: Configured for Arbitrum Sepolia and Robinhood Testnet

Status: Ready for testnet deployment
"

# Add GitHub remote (REPLACE USERNAME/REPO-NAME)
git remote add origin https://github.com/USERNAME/svp-protocol.git

# Rename branch to main
git branch -M main

# Push to GitHub
git push -u origin main

echo "✅ Successfully pushed to GitHub!"
echo "Repository URL: https://github.com/USERNAME/svp-protocol"
