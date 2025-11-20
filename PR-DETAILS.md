# Property Insurance Management System

## Overview
Revolutionary enhancement to the Rent-to-Own Smart Leasing System with integrated **Property Insurance Management**. This new independent feature enables comprehensive insurance coverage for rental properties, protecting both property owners and tenants through smart contract automation.

## Technical Implementation

### Core Data Structures
- **Insurance Policies Map**: Tracks policy details, coverage amounts, premiums, and payment status
- **Insurance Claims Map**: Manages claim filing, processing, and approval workflows
- **Premium Payments Map**: Records premium payment history and timing
- **Policy Payment Counter**: Tracks payment sequences for each policy

### Key Functions Added

#### Public Insurance Functions
- `register-insurance-policy`: Creates new insurance policies for properties
- `pay-insurance-premium`: Processes premium payments with automated policy management  
- `file-insurance-claim`: Enables policy holders to submit insurance claims
- `process-insurance-claim`: Administrative function for claim approval and payout

#### Read-Only Insurance Functions  
- `get-insurance-policy`: Retrieves complete policy information
- `get-insurance-claim`: Fetches claim details and processing status
- `get-policy-status`: Real-time policy status with premium due dates
- `get-total-insurance-policies/claims`: System-wide statistics

### Enhanced Security Features
- **Coverage Validation**: Maximum 200% of property value coverage limit
- **Premium Grace Period**: 144 blocks (~1 day) before policy deactivation
- **Claim Processing Controls**: Only contract owner can approve claims
- **Automated Policy Management**: Self-deactivating policies for overdue premiums

### Smart Contract Integration
- **Independent Operation**: No cross-contract calls or trait dependencies
- **Clarity v3 Compliant**: Proper error constants and data type usage
- **STX Integration**: All payments processed in native STX cryptocurrency
- **Block-based Timing**: Uses Stacks blockchain for payment scheduling

## Testing & Validation
- ✅ Contract passes `clarinet check` with only minor warnings
- ✅ All npm dependencies installed successfully  
- ✅ CI/CD pipeline configured for automated testing
- ✅ Clarity v3 compliant with comprehensive error handling
- ✅ Line endings normalized (CRLF → LF) for cross-platform compatibility

## Insurance Workflow Example

```clarity
;; 1. Property owner registers insurance policy
(contract-call? .rent-to-own-system register-insurance-policy 
  u1              ; Property ID
  u500000         ; Coverage amount (STX)
  u2000           ; Monthly premium (STX)
  u52560)         ; Policy duration (~1 year)

;; 2. Pay monthly premium  
(contract-call? .rent-to-own-system pay-insurance-premium u1)

;; 3. File insurance claim if needed
(contract-call? .rent-to-own-system file-insurance-claim 
  u1 
  u50000 
  "Fire damage to kitchen")

;; 4. Contract owner processes claim
(contract-call? .rent-to-own-system process-insurance-claim u1 u45000)
```

## Business Value
- **Risk Mitigation**: Comprehensive property protection for owners and tenants
- **Automated Management**: Smart contract eliminates manual insurance processes
- **Transparent Claims**: Immutable record of all claims and approvals
- **Cost Efficiency**: Reduced administrative overhead through automation
- **Trust Building**: Blockchain verification increases confidence in insurance system
