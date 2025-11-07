A blockchain-based DAO that empowers informal recyclers through tokenized rewards, transparent supply chains, and collective funding mechanisms.

## 🔥 Problem Solved
- 💰 Informal recyclers are underpaid and lack social protection
- 🔍 Recycling chains lack transparency
- 🚫 Citizens have no incentive to recycle properly

## ✨ Features
- 🪙 **Proof-of-Recycle Token Rewards**: Earn tokens for verified recycling activities
- 🏢 **Collection Center Registry**: Verified centers validate recycling submissions
- 🗳️ **DAO Governance**: Community voting on funding, healthcare, and micro-loans
- 📊 **ESG Data Tracking**: Transparent environmental impact metrics for funders
- 🆘 **Emergency Aid System**: Community-funded emergency relief for recyclers in crisis
- 👥 **Referral Program**: Incentivize community growth through token rewards for successful referrals

## 🚀 Quick Start

### Deploy Contract
```bash
clarinet deploy
```

### Core Functions

#### 🏪 Register Collection Center
```clarity
(contract-call? .recyclers-cooperative-dao register-collection-center "EcoCenter" "Downtown Location")
```

#### ♻️ Submit Recycling
```clarity
(contract-call? .recyclers-cooperative-dao submit-recycling u1 u50 "plastic")
```

#### 💡 Create Proposal
```clarity
(contract-call? .recyclers-cooperative-dao create-proposal "Healthcare Fund" "Medical support for recyclers" u1000 'SP123... "healthcare")
```

#### 🗳️ Vote on Proposal
```clarity
(contract-call? .recyclers-cooperative-dao vote-proposal u1 true)
```

#### 💰 Fund DAO
```clarity
(contract-call? .recyclers-cooperative-dao fund-dao u5000)
```

#### 👥 Generate Referral Code
```clarity
(contract-call? .recyclers-cooperative-dao generate-referral-code)
```

#### 👥 Use Referral Code
```clarity
(contract-call? .recyclers-cooperative-dao use-referral-code "REF1")
```

## � Contract Functions

### 🏗️ Administrative
- `register-collection-center` - Register new collection center
- `verify-collection-center` - Verify center (owner only)
- `fund-dao` - Add funds to DAO treasury

### ♻️ Recycling Operations
- `submit-recycling` - Submit recycling activity for token rewards
- `record-esg-data` - Track environmental impact data

### 🏛️ DAO Governance
- `create-proposal` - Submit governance proposal
- `vote-proposal` - Vote on active proposals
- `execute-proposal` - Execute passed proposals

### 💳 Financial
- `provide-loan` - Automated micro-loans for qualified recyclers
- `repay-loan` - Repay outstanding loans

### 🆘 Emergency Aid
- `contribute-emergency-fund` - Contribute to emergency relief fund
- `request-emergency-aid` - Request emergency financial assistance
- `get-emergency-fund-balance` - Check emergency fund balance

### 👥 Referral Program
- `generate-referral-code` - Generate unique referral code for sharing
- `use-referral-code` - Redeem referral code for token rewards
- `get-referral-code` - Check referral code status
### � Read Functions
- `get-collection-center` - Get center details
- `get-recycler-profile` - Get recycler stats
- `get-proposal` - Get proposal details
- `get-total-recycled` - Get total waste processed
- `get-dao-treasury` - Get treasury balance

## 🎯 Token Economics
- 10 tokens earned per unit of waste recycled
- 50 tokens bonus for successful referrals (25 for referrer, 25 for referee)
- Minimum 100 tokens required to create proposals
- Token balance determines voting weight
- Reputation score affects loan eligibility

## 🔒 Security Features
- Only verified collection centers can validate recycling
- Multi-sig proposal execution
- Reputation-based loan system
- Time-locked voting periods

## 📈 ESG Integration
Funders can track:
- CO2 emissions saved
- Emergency aid system for recyclers facing crises
- Total waste processed
- Individual recycler impact
- Timestamp verification

## 🤝 Contributing
This is an MVP implementation. Recent enhancements include:
- 👥 Referral program for community growth incentives

Future enhancements include:
- Multi-token support
- Advanced reputation algorithms
- Integration with IoT sensors
- Mobile app interface

## 📄 License
MIT License - See LICENSE file for details
