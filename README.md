# Damn Vulnerable DeFi - Foundry Version ⚒️

![Github Actions][gha-badge] [![Telegram Support][tg-support-badge]][tg-support-url]

[gha-badge]: https://img.shields.io/github/workflow/status/nicolasgarcia214/damn-vulnerable-defi-foundry/CI
[tg-support-badge]: https://img.shields.io/endpoint?color=neon&logo=telegram&label=support&style=flat-square&url=https%3A%2F%2Ftg.sumanjay.workers.dev%2Ffoundry_support
[tg-support-url]: https://t.me/foundry_support

[![Twitter Follow](https://img.shields.io/twitter/follow/ngp2311?label=Follow%20me%20%40ngp2311&style=social)](https://twitter.com/ngp2311)

Visit [damnvulnerabledefi.xyz](https://damnvulnerabledefi.xyz)

### Acknowledgement
*Big thanks to [Tincho](https://twitter.com/tinchoabbate) who created the [first version of this game](https://github.com/tinchoabbate/damn-vulnerable-defi/tree/v2.0.0), [Nicolas Garcia](https://github.com/nicolasgarcia214/damn-vulnerable-defi-foundry) and to all the fellows behind the [Foundry Framework](https://github.com/gakonst/foundry/graphs/contributors)*

Damn Vulnerable DeFi is the wargame to learn offensive security of DeFi smart contracts.

Throughout numerous challenges you will build the skills to become a bug hunter or security auditor in the space. 🕵️‍♂️

## How To Play 🕹️

1.  **Install Foundry**

First run the command below to get foundryup, the Foundry toolchain installer:

``` bash
curl -L https://foundry.paradigm.xyz | bash
```

Then, in a new terminal session or after reloading your PATH, run it to get the latest forge and cast binaries:

``` console
foundryup
```
Advanced ways to use `foundryup`, and other documentation, can be found in the [foundryup package](./foundryup/README.md)

2. **Clone This Repo and install dependencies**
``` 
git clone https://github.com/Ellahinator/damn-vulnerable-defi-foundry.git
cd damn-vulnerable-defi-foundry
forge install
yarn install
```
3. **Run tests**
```
forge test
```
or
```
forge test --match-contract [CONTRACT_LEVEL_NAME]
```

