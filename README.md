# fractional-nouns

## Background

This repository houses a set of smart contracts that enable proportional voting over Nouns proposals and PFP collection of Nouns via fractionalized ownership of the Nouns token.

### More Information

- Link to the proposal: [Nouns Proposal #537](https://nouns.wtf/vote/537)

- Medium Blog Post 1: [$⌐◧-◧: Introducing Fractional Ownership & Governance of Nouns](https://medium.com/@NobleDev/introducing-fractional-ownership-governance-of-nouns-ddebe817b2f0)

- Medium Blog Post 2: [$⌐◧-◧: Smart Contract Design](https://medium.com/@NobleDev/smart-contract-design-535d45132995)

## Quick start

The first things you need to do are cloning this repository and installing its dependencies:

```sh
git clone https://github.com/TheNobleDev/fractional-nouns.git
cd fractional-nouns
npm install
```

Once installed, compile the code:

```sh
npx hardhat compile
```

Then, to run tests and check coverage:

```sh
npx hardhat coverage
```

Finally, to deploy the contracts:

```sh
npx hardhat run scripts/deploy.js --network <network of choice>
```

Note: You may have to edit the deploy script with the right dependency addresses

## Testnet Deployment

The contracts (old buggy version) deployed on Sepolia testnet are:

- NounsFragmentToken: `0x661290d6f8c8490419cd5d92f01d507f402189c1`
- NounsFungibleToken: `0x826595D1c7D3506c808263d28Fde788f4d140B0f`
- NounsFragmentManager (Implementation): `0x1c83F10AFa8cfd7c48Ba0075682faD0a98Ed7E33`
- NounsFragmentManager (Proxy): `0x4Df1Da96fD0a7F56380bAD3bab47898de4F6DFF8`
