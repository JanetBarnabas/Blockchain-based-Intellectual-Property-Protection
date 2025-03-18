# 🎨 Blockchain-based IP Protection

Welcome to the coolest way to protect your creative works on the blockchain! This project lets creators timestamp and prove ownership of their intellectual property using the Stacks blockchain.

## ✨ Features

- 🔐 Register your work with a unique hash
- ⏰ Immutable timestamp proof of creation
- 📝 Store title and description of your work
- ✅ Verify ownership instantly
- 🚫 Prevent duplicate registrations

## 🛠 How It Works

### For Creators
1. Generate a SHA-256 hash of your work
2. Call `register-work` with:
   - Your work's hash
   - A catchy title
   - An awesome description
3. Boom! Your work is now protected on the blockchain

### For Verifiers
1. Use `get-work-details` to view registration info
2. Call `verify-ownership` to confirm creator rights
3. That's it! Instant verification
