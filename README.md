# 🏠 Rent-to-Own Smart Leasing System

A revolutionary Clarity smart contract that transforms traditional renting into a pathway to homeownership. Built on the Stacks blockchain, this system enables tenants to build equity with each rent payment while providing transparency and automated contract enforcement.

## 🌟 Features

- **🔄 Automated Equity Building** - A portion of each rent payment automatically converts to property equity
- **📊 Transparent Progress Tracking** - Real-time visibility into ownership progress
- **⚡ Automated Ownership Transfer** - Seamless property ownership transfer when equity threshold is reached
- **🎯 Smart Penalty System** - Late payment penalties and early exit fees to maintain contract integrity
- **🎁 Completion Bonuses** - Rewards for completing lease terms successfully
- **🔒 Secure & Immutable** - All transactions and ownership records secured on the blockchain

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://docs.hiro.so/stacks/clarinet) installed
- [Stacks Wallet](https://wallet.hiro.so/) for interacting with the contract

### Installation

1. Clone the repository:
```bash
git clone https://github.com/shavonpam1/Rent-to-Own-Smart-Leasing-System.git
cd Rent-to-Own-Smart-Leasing-System
```

2. Check contract compilation:
```bash
clarinet check
```

3. Run tests:
```bash
npm install
npm test
```

## 📝 Usage Guide

### For Property Owners

#### 1. Register a Property
```clarity
(contract-call? .Rent-to-Own-Smart-Leasing-System register-property 
  "123 Main St, City" 
  u1000000     ; Property value in STX
  u5000        ; Monthly rent in STX
  u30)         ; Equity rate (30% of rent goes to equity)
```

#### 2. Create a Lease
```clarity
(contract-call? .Rent-to-Own-Smart-Leasing-System create-lease 
  u1                     ; Property ID
  'ST1TENANT123...       ; Tenant principal
  u52560)                ; Lease duration in blocks (~1 year)
```

### For Tenants

#### 1. Make Monthly Payments
```clarity
(contract-call? .Rent-to-Own-Smart-Leasing-System make-payment u1)
```

#### 2. Check Equity Progress
```clarity
(contract-call? .Rent-to-Own-Smart-Leasing-System get-equity-progress u1)
```

#### 3. Complete Lease (with bonus)
```clarity
(contract-call? .Rent-to-Own-Smart-Leasing-System complete-lease u1)
```

#### 4. Early Exit (with penalty)
```clarity
(contract-call? .Rent-to-Own-Smart-Leasing-System early-exit u1)
```

## 🔍 Key Functions

### Public Functions

| Function | Description | Who Can Call |
|----------|-------------|--------------|
| `register-property` | Register a new rental property | Property owners |
| `create-lease` | Create a new rent-to-own lease | Property owners |
| `make-payment` | Make monthly rent payment | Tenants |
| `early-exit` | Exit lease early with penalty | Tenants |
| `complete-lease` | Complete lease with bonus | Tenants |

### Read-Only Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `get-property` | Get property details | Property info |
| `get-lease` | Get lease details | Lease info |
| `get-equity-progress` | Check ownership progress | Equity status |
| `get-next-payment-due` | Check next payment timing | Payment schedule |
| `calculate-penalty` | Calculate late payment penalty | Penalty amount |

## 💰 Economic Model

### Equity Allocation
- **Base Rate**: Set per property (e.g., 30% of rent → equity)
- **Late Payments**: Penalty applied, but base equity still allocated
- **On-Time Bonus**: Full payment amount contributes to equity calculation

### Penalties & Rewards
- **Late Payment Penalty**: 5% of monthly rent
- **Early Exit Penalty**: 15% of accumulated equity
- **Completion Bonus**: 10% of accumulated equity

### Ownership Transfer
- **Threshold**: 80% of property value
- **Automatic**: Transfer occurs when threshold reached
- **Immediate**: No additional paperwork or delays

## 📊 Example Scenario

**Property**: $100,000 value, $500/month rent, 30% equity rate

| Month | Payment | Equity Added | Total Equity | Progress |
|-------|---------|--------------|--------------|----------|
| 1 | $500 | $150 | $150 | 0.2% |
| 12 | $500 | $150 | $1,800 | 2.3% |
| 60 | $500 | $150 | $9,000 | 11.3% |
| 534 | $500 | $150 | $80,100 | **100%** 🎉 |

*Ownership achieved in ~44 years with consistent payments*

## ⚠️ Important Notes

- **Block Timing**: Payments expected every 1,008 blocks (~1 week)
- **Grace Period**: 144 blocks (~1 day) before late penalty applies  
- **STX Transfers**: All payments processed in STX cryptocurrency
- **Immutable Records**: All transactions permanently recorded on blockchain

## 🧪 Testing

The contract includes comprehensive test coverage:

```bash
# Run all tests
npm test

# Check contract syntax
clarinet check

# Interactive testing
clarinet console
```

## 🔒 Security Features

- **Access Control**: Only authorized parties can call specific functions
- **Parameter Validation**: All inputs validated before processing
- **Safe Math**: Overflow protection on all calculations
- **Reentrancy Protection**: Safe external calls and state updates

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🆘 Support

- **Documentation**: [Stacks Docs](https://docs.stacks.co/)
- **Community**: [Stacks Discord](https://discord.gg/stacks)
- **Issues**: [GitHub Issues](https://github.com/shavonpam1/Rent-to-Own-Smart-Leasing-System/issues)

---

**Built with ❤️ on Stacks** | **Making homeownership accessible through blockchain innovation** 🚀
