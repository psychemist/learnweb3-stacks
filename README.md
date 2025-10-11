# LearnWeb3 Stacks Projects

This repository contains a collection of projects built on the Stacks blockchain as part of the LearnWeb3 learning journey.

## Projects

### 1. Stacks Account History

A Next.js web application for viewing Stacks account transaction history.

**Tech Stack:**
- Next.js 15 with React 19
- TypeScript
- Stacks.js (@stacks/connect, @stacks/transactions)
- Tailwind CSS

**Features:**
- Connect wallet integration
- View transaction history for any Stacks address
- Link to Hiro Explorer for detailed transaction information

**Getting Started:**
```bash
cd stacks-account-history
npm install
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) to view the application.

**Available Scripts:**
- `npm run dev` - Start development server
- `npm run build` - Build for production
- `npm run start` - Start production server
- `npm run lint` - Run linter

---

### 2. Stacks Token Streaming

A Clarity smart contract implementation for creating and managing STX token streams.

**Tech Stack:**
- Clarity smart contracts
- Clarinet SDK
- Vitest for testing
- TypeScript

**Features:**
- Create token streams with defined payment schedules
- Withdraw tokens from active streams
- Refuel streams with additional tokens
- Cancel streams and reclaim unused funds
- Signature-based stream modifications

**Getting Started:**
```bash
cd stacks-token-streaming
npm install
npm test
```

**Available Scripts:**
- `npm test` - Run tests
- `npm run test:report` - Run tests with coverage and cost reports
- `npm run test:watch` - Watch mode for continuous testing

**Contract:** `contracts/stream.clar`

---

### 3. Tic-Stacks-Toe

An on-chain Tic Tac Toe game implementation using Clarity smart contracts.

**Tech Stack:**
- Clarity smart contracts
- Clarinet SDK
- Vitest for testing
- TypeScript

**Features:**
- Create games with customizable bet amounts
- Two-player gameplay with turn-based moves
- On-chain game state management
- Winner determination and payout
- Minimum bet validation

**Getting Started:**
```bash
cd tic-stacks-toe
npm install
npm test
```

**Available Scripts:**
- `npm test` - Run tests
- `npm run test:report` - Run tests with coverage and cost reports
- `npm run test:watch` - Watch mode for continuous testing

**Contract:** `contracts/tic-tac-toe.clar`

---

## About

These projects demonstrate various aspects of blockchain development on Stacks:
- **Frontend development** with Stacks integration
- **Smart contract development** using Clarity
- **Testing and deployment** practices for blockchain applications

## Resources

- [Stacks Documentation](https://docs.stacks.co/)
- [Clarity Language Reference](https://docs.stacks.co/clarity/)
- [LearnWeb3](https://learnweb3.io/)
