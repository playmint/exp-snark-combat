/** @format */
import { Fragment, useState, useEffect, createContext, useContext } from 'react';
import type { NextPage } from 'next';
import Head from 'next/head';
import { Web3Provider } from '@ethersproject/providers';
// import { utils } from 'ethers';
import {
    Dungeon as DungeonContract,
    Dungeon__factory,
    Seeker as SeekerContract,
    Seeker__factory
} from '@app/services/contracts';
import { Web3ReactProvider, useWeb3React } from '@web3-react/core';
import { Web3ReactContextInterface } from '@web3-react/core/dist/types';
import { InjectedConnector } from '@web3-react/injected-connector';
import * as circomlib from 'circomlibjs';

const numSeekers = 3;
const numTicks = 100;
let snarkjs: any; // loaded from window

// enum Alignment {
//     NONE,
//     LIGHT,
//     DARK,
//     ORDER,
//     CHAOS,
//     ARCANE
// }

enum ActionKind {
    ENTER,
    EQUIP,
    DRINK,
    LEAVE
}

interface CombatState {
    dungeonArmour: number;
    dungeonHealth: number;
    seekerArmour: number;
    seekerHealth: number;
    slot: number;
    tick: number;
    pi_a: number[];
    pi_b: number[][];
    pi_c: number[];
}

interface DeploymentConfig {
    contracts: {
        dungeon: {
            address: string;
        };
        seeker: {
            address: string;
        };
        rune: {
            address: string;
        };
    };
}

const injectedConnector = new InjectedConnector({
    supportedChainIds: [5]
});

const getLibrary = (provider: any): Web3Provider => {
    return new Web3Provider(provider);
};

interface IContractProviderContext {
    dungeonContract: DungeonContract;
    seekerContract: SeekerContract;
}

const ContractProviderContext = createContext({} as IContractProviderContext);

interface ContractProviderProps {
    children?: React.ReactNode;
    config: DeploymentConfig;
}
const ContractProvider = (props: ContractProviderProps) => {
    const { config, children } = props;
    const { library } = useWeb3React();

    const signer = library ? library.getSigner() : library;

    const dungeonContract = Dungeon__factory.connect(config.contracts.dungeon.address, signer);
    const seekerContract = Seeker__factory.connect(config.contracts.seeker.address, signer);

    const state = {
        dungeonContract,
        seekerContract
    };

    return <ContractProviderContext.Provider value={state}>{children}</ContractProviderContext.Provider>;
};

export const Login = (): JSX.Element => {
    const provider = useWeb3React();

    const connectionStatus = (provider: Web3ReactContextInterface): string => {
        if (provider.error) {
            return provider.error.message;
        } else if (provider.active) {
            return `connected ${provider.chainId}`;
        } else {
            return 'connect';
        }
    };

    const onClickConnect = () => {
        provider.activate(injectedConnector);
    };

    useEffect(() => {
        provider.activate(injectedConnector);
    }, [provider.account]);

    return (
        <ul className="box">
            <li className="box-item">
                <span>wallet: </span>
                <button onClick={onClickConnect}>{connectionStatus(provider)}</button>
            </li>
        </ul>
    );
};

// interface ClaimButtonProps {
//     dungeonId: number;
//     relicIds: number[];
//     raidTokenId: number;
//     coupon: string;
// }
// const ClaimButton = (props: ClaimButtonProps): JSX.Element => {
//     const { dungeonContract } = useContext(ContractProviderContext);
//     const { dungeonId, raidTokenId, relicIds, coupon } = props;

//     const claim = async () => {
//         const sig = utils.splitSignature(coupon);
//         const msg = utils.arrayify(
//             utils.keccak256(
//                 utils.defaultAbiCoder.encode(['uint256', 'uint256', 'uint256[]'], [dungeonId, raidTokenId, relicIds])
//             )
//         );
//         console.log('ClaimSigner:', utils.verifyMessage(msg, sig));
//         const { v, r, s } = sig;
//         console.log('sig', v, r, s);
//         return dungeonContract.claimRune(dungeonId, raidTokenId, relicIds, v, r, s);
//     };

//     const handleClaim = () => {
//         claim()
//             .then(() => console.log('claimed', relicIds))
//             .catch((err) => console.error(err));
//     };

//     const label = (() => {
//         return `Claim ${relicIds.length} relics from conquering Dungeon ${orderSuffixes[dungeonId]}`;
//     })();

//     return (
//         <div className="box-item">
//             <button onClick={handleClaim}>{label}</button>
//         </div>
//     );
// };

interface ActionButtonProps {
    kind: ActionKind;
    slotID: number;
    attackRuneID: number;
    armourRuneID: number;
    healthRuneID: number;
    label: string;
    disabled: boolean;
}
const ActionButton = (props: ActionButtonProps): JSX.Element => {
    const { dungeonContract } = useContext(ContractProviderContext);
    const { label, disabled, kind, slotID, attackRuneID, armourRuneID, healthRuneID } = props;

    const send = async () => {
        return dungeonContract.send(kind, slotID, attackRuneID, armourRuneID, healthRuneID);
    };

    const handleSend = () => {
        send()
            .then(() => {
                console.log('committed', kind, slotID, attackRuneID);
            })
            .catch((err) => console.error(err));
    };

    return (
        <div>
            <button disabled={disabled} onClick={handleSend}>
                {label}
            </button>
        </div>
    );
};

export const Main = (): JSX.Element => {
    const { library } = useWeb3React();
    const { account } = useWeb3React();
    console.log('account', account);
    const { seekerContract, dungeonContract } = useContext(ContractProviderContext);
    const [gameState, setGameState] = useState({} as CombatState);

    const mintSeeker = async () => {
        if (!account) {
            console.error('no account');
            return;
        }
        const tx = await seekerContract.mint(account, 1, [
            2, // str
            2, // tough
            3, // dex
            4, // speed
            5, // vit
            6, // endur
            7, // order
            0 // corruption (ignored)
        ]);
        return tx.wait();
    };

    const handleMintSeeker = () => {
        mintSeeker()
            .then(() => console.log('minted'))
            .catch((err) => console.error(err));
    };

    const getCurrentTick = async (): Promise<number> => {
        const battleStart = await dungeonContract.dungeonBattleStart().then((n) => n.toNumber());
        const currentBlock = await library.getBlockNumber();
        return currentBlock - battleStart;
    };

    const getGameState = async (tick?: number): Promise<CombatState> => {
        // fetch all the Action events
        const events = await dungeonContract.queryFilter(dungeonContract.filters.Action(), 0, 500);
        // group the Actions by their seeker slot
        const slots = events.reduce(
            (slots, { args }) => {
                const [
                    kind,
                    slotID,
                    [tick, dungeonAttackArmour, dungeonAttackHealth, seekerAttackArmour, seekerAttackHealth]
                ] = args;
                slots[slotID].push({
                    kind,
                    tick,
                    dungeonAttackArmour,
                    dungeonAttackHealth,
                    seekerAttackArmour,
                    seekerAttackHealth
                });
                return slots;
            },
            Array(numSeekers)
                .fill(null)
                .map(() => [] as any)
        );
        // console.log('actions', slots);
        // fetch the current block and convert to ticks since battle started
        const currentTick = Math.min(tick ? tick : await getCurrentTick(), 99);
        // expand each action to cover each tick
        // (this is the input the circuit needs)
        const currentSeeker = 0; // generate health for this slot (the seeker we care about)
        const inputs = await generateInputs(slots, currentSeeker, currentTick);
        // evaluate the circuit / build proof to get the valid outputs
        //
        // witness
        const wtns = { type: 'mem' };
        await snarkjs.wtns.calculate(inputs, 'combat_js/combat.wasm', wtns);
        // proof
        const zkey_final = 'combat_0001.zkey';
        const outputs = await snarkjs.groth16.prove(zkey_final, wtns);
        // now we have the public signals and can build the current verified state
        const [
            dungeonArmour,
            dungeonHealth,
            seekerArmour,
            seekerHealth,
            _slot0ValuesHash,
            _slot1ValuesHash,
            _slot2ValuesHash
        ] = outputs.publicSignals;
        // verify the proof
        // const vKey = JSON.parse(fs.readFileSync(path.join("..", "verification_key.json")).toString());
        // const verification = await snarkjs.groth16.verify(vKey, outputs.publicSignals, outputs.proof);
        // expect(verification).to.be.true;
        const state = {
            dungeonArmour: parseInt(dungeonArmour, 10),
            dungeonHealth: parseInt(dungeonHealth, 10),
            seekerArmour: parseInt(seekerArmour, 10),
            seekerHealth: parseInt(seekerHealth, 10),
            tick: currentTick,
            slot: currentSeeker,
            pi_a: [outputs.proof.pi_a[0], outputs.proof.pi_a[1]],
            pi_b: [
                [outputs.proof.pi_b[0][1], outputs.proof.pi_b[0][0]],
                [outputs.proof.pi_b[1][1], outputs.proof.pi_b[1][0]]
            ],
            pi_c: [outputs.proof.pi_c[0], outputs.proof.pi_c[1]]
        };
        // console.log('state', state);
        return state;
    };

    const generateInputs = async (slots: any, currentSeeker: number, currentTick: number) => {
        // convert actions into expanded list of all inputs at each tick per seeker
        const inputs = {
            dungeonAttackArmour: Array(numTicks)
                .fill(null)
                .map(() => Array(numSeekers).fill(0)),
            dungeonAttackHealth: Array(numTicks)
                .fill(null)
                .map(() => Array(numSeekers).fill(0)),
            seekerAttackArmour: Array(numTicks)
                .fill(null)
                .map(() => Array(numSeekers).fill(0)),
            seekerAttackHealth: Array(numTicks)
                .fill(null)
                .map(() => Array(numSeekers).fill(0)),
            currentSeeker,
            currentTick,
            seekerValuesHash: Array(numSeekers).fill(null),
            seekerValuesUpdated: Array(numTicks)
                .fill(null)
                .map(() => Array(numSeekers).fill(0))
        };
        for (let s = 0; s < numSeekers; s++) {
            const actions = slots[s];
            let inputValuesHash = 0;
            const poseidon = await circomlib.buildPoseidon();

            for (let a = 0; a < actions.length; a++) {
                const action = actions[a];
                // console.log('seeker', s, action);
                if (action.kind == ActionKind.ENTER || action.kind == ActionKind.EQUIP) {
                    // console.log('hash bfr', poseidon.F.toString(inputValuesHash));
                    const h = [
                        inputValuesHash,
                        action.dungeonAttackArmour,
                        action.dungeonAttackHealth,
                        action.seekerAttackArmour,
                        action.seekerAttackHealth,
                        action.tick
                    ];
                    inputValuesHash = poseidon(h);
                    inputs.seekerValuesUpdated[action.tick][s] = 1;
                    // console.log('hash afr', poseidon.F.toString(inputValuesHash), h);
                }
                for (let t = action.tick; t < numTicks; t++) {
                    inputs.dungeonAttackArmour[t][s] = action.dungeonAttackArmour;
                    inputs.dungeonAttackHealth[t][s] = action.dungeonAttackHealth;
                    inputs.seekerAttackArmour[t][s] = action.seekerAttackArmour;
                    inputs.seekerAttackHealth[t][s] = action.seekerAttackHealth;
                }
            }

            inputs.seekerValuesHash[s] = inputValuesHash === 0 ? 0 : poseidon.F.toString(inputValuesHash);
        }

        return inputs;
    };

    // const handleRaidSuccess = () => {
    //     refetch()
    //         .then(() => console.log('refetched'))
    //         .catch((err) => console.error(err));
    // };

    useEffect(() => {
        if (!library) {
            return;
        }
        library.on('block', () => {
            getGameState()
                .then((gameState) => setGameState(gameState))
                .catch((err) => console.log('failed to getGameState:', err));
        });
    }, [library]);

    const seekers: any[] = [];

    return (
        <div>
            <div className="box">
                <button className="box-item" onClick={handleMintSeeker}>
                    Mint Seeker
                </button>
            </div>
            <div className="dungeons">
                {seekers.map((idx) => (
                    <div key={idx} className="dungeon-card">
                        <p> Seeker in Slot {idx}</p>
                        <p> Health: x</p>
                        <p> Strength (against armour): x</p>
                        <p> Strength (against health): x</p>
                        <ActionButton
                            slotID={idx}
                            kind={ActionKind.ENTER}
                            label="Join"
                            attackRuneID={0}
                            armourRuneID={0}
                            healthRuneID={0}
                            disabled={false}
                        />
                    </div>
                ))}
            </div>
            <div className="state">
                <p>seeker: {gameState.slot}</p>
                <p>tick: {gameState.tick}</p>
                <p>dungeonArmour: {gameState.dungeonArmour}</p>
                <p>dungeonHealth: {gameState.dungeonHealth}</p>
                <p>seekerArmour: {gameState.seekerArmour}</p>
                <p>seekerHealth: {gameState.seekerHealth}</p>
            </div>
        </div>
    );
};

const App: NextPage = () => {
    const [config, setConfig] = useState(null as any);

    // load the config from the compiled deployment artefacts
    // if this file is missing then you probably need to redeploy
    useEffect(() => {
        ({ snarkjs } = window as any); // can't load via webpack :shrug:
        import(`../../../contracts/deployments/localhost.json`)
            .then((mod) => setConfig(mod.default as DeploymentConfig))
            .catch((err) => console.error('failed to load contract config', err));
    }, []);

    if (!config) {
        return <div>loading</div>;
    }

    return (
        <Fragment>
            <Head>
                <title>SNARKCombat</title>
            </Head>
            <link rel="preconnect" href="https://fonts.googleapis.com" />
            <link rel="preconnect" href="https://fonts.gstatic.com" crossOrigin="crossOrigin" />
            <link
                href="https://fonts.googleapis.com/css2?family=Libre+Baskerville:ital,wght@0,400;0,700;1,400&display=swap"
                rel="stylesheet"
            />
            <script src="snarkjs.min.js"></script>
            <Web3ReactProvider getLibrary={getLibrary}>
                <ContractProvider config={config as DeploymentConfig}>
                    <div id="backplate">
                        <video src="/backplate.mp4" autoPlay={true} loop={true} muted={true} />
                    </div>
                    <div id="main">
                        <h1>The Crypt Lite</h1>
                        <Login />
                        <Main />
                    </div>
                </ContractProvider>
            </Web3ReactProvider>
        </Fragment>
    );
};

export default App;
