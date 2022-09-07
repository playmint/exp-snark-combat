/* Autogenerated file. Do not edit manually. */
/* tslint:disable */
/* eslint-disable */
import { Signer, utils, Contract, ContractFactory, Overrides } from "ethers";
import type { Provider, TransactionRequest } from "@ethersproject/providers";
import type { PromiseOrValue } from "../../common";
import type { Rune, RuneInterface } from "../../src/Rune";

const _abi = [
  {
    inputs: [],
    stateMutability: "nonpayable",
    type: "constructor",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "owner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "approved",
        type: "address",
      },
      {
        indexed: true,
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "Approval",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "owner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "operator",
        type: "address",
      },
      {
        indexed: false,
        internalType: "bool",
        name: "approved",
        type: "bool",
      },
    ],
    name: "ApprovalForAll",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "previousOwner",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "OwnershipTransferred",
    type: "event",
  },
  {
    anonymous: false,
    inputs: [
      {
        indexed: true,
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        indexed: true,
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        indexed: true,
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "Transfer",
    type: "event",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    name: "alignments",
    outputs: [
      {
        internalType: "enum Alignment",
        name: "",
        type: "uint8",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "approve",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "owner",
        type: "address",
      },
    ],
    name: "balanceOf",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "contractURI",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "pure",
    type: "function",
  },
  {
    inputs: [],
    name: "count",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "exists",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "getAlignment",
    outputs: [
      {
        internalType: "enum Alignment",
        name: "",
        type: "uint8",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "getApproved",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "owner",
        type: "address",
      },
      {
        internalType: "address",
        name: "operator",
        type: "address",
      },
    ],
    name: "isApprovedForAll",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "enum Alignment",
        name: "alignment",
        type: "uint8",
      },
    ],
    name: "mint",
    outputs: [
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [],
    name: "name",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "owner",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "ownerOf",
    outputs: [
      {
        internalType: "address",
        name: "",
        type: "address",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "renounceOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "safeTransferFrom",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
      {
        internalType: "bytes",
        name: "data",
        type: "bytes",
      },
    ],
    name: "safeTransferFrom",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "operator",
        type: "address",
      },
      {
        internalType: "bool",
        name: "approved",
        type: "bool",
      },
    ],
    name: "setApprovalForAll",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "bytes4",
        name: "interfaceId",
        type: "bytes4",
      },
    ],
    name: "supportsInterface",
    outputs: [
      {
        internalType: "bool",
        name: "",
        type: "bool",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "symbol",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "index",
        type: "uint256",
      },
    ],
    name: "tokenByIndex",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "owner",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "index",
        type: "uint256",
      },
    ],
    name: "tokenOfOwnerByIndex",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "tokenURI",
    outputs: [
      {
        internalType: "string",
        name: "",
        type: "string",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [],
    name: "totalSupply",
    outputs: [
      {
        internalType: "uint256",
        name: "",
        type: "uint256",
      },
    ],
    stateMutability: "view",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "from",
        type: "address",
      },
      {
        internalType: "address",
        name: "to",
        type: "address",
      },
      {
        internalType: "uint256",
        name: "tokenId",
        type: "uint256",
      },
    ],
    name: "transferFrom",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
  {
    inputs: [
      {
        internalType: "address",
        name: "newOwner",
        type: "address",
      },
    ],
    name: "transferOwnership",
    outputs: [],
    stateMutability: "nonpayable",
    type: "function",
  },
];

const _bytecode =
  "0x60806040523480156200001157600080fd5b5060408051808201825260048082526352756e6560e01b6020808401828152855180870190965292855284015281519192916200005191600091620000e0565b50805162000067906001906020840190620000e0565b505050620000846200007e6200008a60201b60201c565b6200008e565b620001c3565b3390565b600a80546001600160a01b038381166001600160a01b0319831681179093556040519116919082907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e090600090a35050565b828054620000ee9062000186565b90600052602060002090601f0160209004810192826200011257600085556200015d565b82601f106200012d57805160ff19168380011785556200015d565b828001600101855582156200015d579182015b828111156200015d57825182559160200191906001019062000140565b506200016b9291506200016f565b5090565b5b808211156200016b576000815560010162000170565b600181811c908216806200019b57607f821691505b60208210811415620001bd57634e487b7160e01b600052602260045260246000fd5b50919050565b61200480620001d36000396000f3fe608060405234801561001057600080fd5b50600436106101735760003560e01c80636352211e116100de57806395d89b4111610097578063c87b56dd11610071578063c87b56dd14610346578063e8a3d48514610359578063e985e9c514610361578063f2fde38b1461039d57600080fd5b806395d89b4114610318578063a22cb46514610320578063b88d4fde1461033357600080fd5b80636352211e146102a3578063691562a0146102b657806370a08231146102c9578063715018a6146102dc578063829080b9146102e45780638da5cb5b1461030757600080fd5b806323b872dd1161013057806323b872dd1461021457806327257c75146102275780632f745c591461025757806342842e0e1461026a5780634f558e791461027d5780634f6ccce71461029057600080fd5b806301ffc9a71461017857806306661abd146101a057806306fdde03146101b7578063081812fc146101cc578063095ea7b3146101f757806318160ddd1461020c575b600080fd5b61018b610186366004611862565b6103b0565b60405190151581526020015b60405180910390f35b6101a9600b5481565b604051908152602001610197565b6101bf6103db565b60405161019791906118de565b6101df6101da3660046118f1565b61046d565b6040516001600160a01b039091168152602001610197565b61020a610205366004611926565b610494565b005b6008546101a9565b61020a610222366004611950565b6105af565b61024a6102353660046118f1565b6000908152600c602052604090205460ff1690565b60405161019791906119a2565b6101a9610265366004611926565b6105e0565b61020a610278366004611950565b610676565b61018b61028b3660046118f1565b610691565b6101a961029e3660046118f1565b6106b0565b6101df6102b13660046118f1565b610743565b6101a96102c43660046119ca565b6107a3565b6101a96102d7366004611a05565b6107f8565b61020a61087e565b61024a6102f23660046118f1565b600c6020526000908152604090205460ff1681565b600a546001600160a01b03166101df565b6101bf610892565b61020a61032e366004611a20565b6108a1565b61020a610341366004611a67565b6108b0565b6101bf6103543660046118f1565b6108e8565b6101bf6109b8565b61018b61036f366004611b43565b6001600160a01b03918216600090815260056020908152604080832093909416825291909152205460ff1690565b61020a6103ab366004611a05565b610aec565b60006001600160e01b0319821663780e9d6360e01b14806103d557506103d582610b65565b92915050565b6060600080546103ea90611b76565b80601f016020809104026020016040519081016040528092919081815260200182805461041690611b76565b80156104635780601f1061043857610100808354040283529160200191610463565b820191906000526020600020905b81548152906001019060200180831161044657829003601f168201915b5050505050905090565b600061047882610bb5565b506000908152600460205260409020546001600160a01b031690565b600061049f82610743565b9050806001600160a01b0316836001600160a01b031614156105125760405162461bcd60e51b815260206004820152602160248201527f4552433732313a20617070726f76616c20746f2063757272656e74206f776e656044820152603960f91b60648201526084015b60405180910390fd5b336001600160a01b038216148061052e575061052e813361036f565b6105a05760405162461bcd60e51b815260206004820152603d60248201527f4552433732313a20617070726f76652063616c6c6572206973206e6f7420746f60448201527f6b656e206f776e6572206f7220617070726f76656420666f7220616c6c0000006064820152608401610509565b6105aa8383610c14565b505050565b6105b93382610c82565b6105d55760405162461bcd60e51b815260040161050990611bb1565b6105aa838383610d01565b60006105eb836107f8565b821061064d5760405162461bcd60e51b815260206004820152602b60248201527f455243373231456e756d657261626c653a206f776e657220696e646578206f7560448201526a74206f6620626f756e647360a81b6064820152608401610509565b506001600160a01b03919091166000908152600660209081526040808320938352929052205490565b6105aa838383604051806020016040528060008152506108b0565b6000818152600260205260408120546001600160a01b031615156103d5565b60006106bb60085490565b821061071e5760405162461bcd60e51b815260206004820152602c60248201527f455243373231456e756d657261626c653a20676c6f62616c20696e646578206f60448201526b7574206f6620626f756e647360a01b6064820152608401610509565b6008828154811061073157610731611bfe565b90600052602060002001549050919050565b6000818152600260205260408120546001600160a01b0316806103d55760405162461bcd60e51b8152602060048201526018602482015277115490cdcc8c4e881a5b9d985b1a59081d1bdad95b88125160421b6044820152606401610509565b600b8054600091826107b483611c2a565b9091555050600b546000818152600c602052604090208054919250839160ff191660018360058111156107e9576107e961198c565b02179055506103d58382610eb2565b60006001600160a01b0382166108625760405162461bcd60e51b815260206004820152602960248201527f4552433732313a2061646472657373207a65726f206973206e6f7420612076616044820152683634b21037bbb732b960b91b6064820152608401610509565b506001600160a01b031660009081526003602052604090205490565b610886610ecc565b6108906000610f26565b565b6060600180546103ea90611b76565b6108ac338383610f78565b5050565b6108ba3383610c82565b6108d65760405162461bcd60e51b815260040161050990611bb1565b6108e284848484611047565b50505050565b6000818152600260205260409020546060906001600160a01b03166109455760405162461bcd60e51b81526020600482015260136024820152721d1bdad95b88191bd95cdb89dd08195e1a5cdd606a1b6044820152606401610509565b6000828152600c602052604090205460ff166109916109638461107a565b61096c83611178565b60405160200161097d929190611c45565b6040516020818303038152906040526111ba565b6040516020016109a19190611d58565b604051602081830303815290604052915050919050565b6060604051602001610ad8907f646174613a6170706c69636174696f6e2f6a736f6e3b757466382c7b226e616d81527f65223a202252756e65222c226465736372697074696f6e223a202252756e657360208201527f222c22696d616765223a202268747470733a2f2f6578616d706c652e636f6d2f6040820152681b9bdd0b5cd95d088b60ba1b60608201527f2265787465726e616c5f6c696e6b223a202268747470733a2f2f6578616d706c60698201526e194b98dbdb4bdb9bdd0b5cd95d088b608a1b60898201527f2273656c6c65725f6665655f62617369735f706f696e7473223a202230222c00609882015275113332b2afb932b1b4b834b2b73a111d1011183c181160511b60b7820152607d60f81b60cd82015260ce0190565b604051602081830303815290604052905090565b610af4610ecc565b6001600160a01b038116610b595760405162461bcd60e51b815260206004820152602660248201527f4f776e61626c653a206e6577206f776e657220697320746865207a65726f206160448201526564647265737360d01b6064820152608401610509565b610b6281610f26565b50565b60006001600160e01b031982166380ac58cd60e01b1480610b9657506001600160e01b03198216635b5e139f60e01b145b806103d557506301ffc9a760e01b6001600160e01b03198316146103d5565b6000818152600260205260409020546001600160a01b0316610b625760405162461bcd60e51b8152602060048201526018602482015277115490cdcc8c4e881a5b9d985b1a59081d1bdad95b88125160421b6044820152606401610509565b600081815260046020526040902080546001600160a01b0319166001600160a01b0384169081179091558190610c4982610743565b6001600160a01b03167f8c5be1e5ebec7d5bd14f71427d1e84f3dd0314c0f7b2291e5b200ac8c7c3b92560405160405180910390a45050565b600080610c8e83610743565b9050806001600160a01b0316846001600160a01b03161480610cd557506001600160a01b0380821660009081526005602090815260408083209388168352929052205460ff165b80610cf95750836001600160a01b0316610cee8461046d565b6001600160a01b0316145b949350505050565b826001600160a01b0316610d1482610743565b6001600160a01b031614610d3a5760405162461bcd60e51b815260040161050990611d9d565b6001600160a01b038216610d9c5760405162461bcd60e51b8152602060048201526024808201527f4552433732313a207472616e7366657220746f20746865207a65726f206164646044820152637265737360e01b6064820152608401610509565b610da7838383611320565b826001600160a01b0316610dba82610743565b6001600160a01b031614610de05760405162461bcd60e51b815260040161050990611d9d565b600081815260046020908152604080832080546001600160a01b03191690556001600160a01b038616835260039091528120805460019290610e23908490611de2565b90915550506001600160a01b0382166000908152600360205260408120805460019290610e51908490611df9565b909155505060008181526002602052604080822080546001600160a01b0319166001600160a01b0386811691821790925591518493918716917fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef91a4505050565b6108ac8282604051806020016040528060008152506113d8565b600a546001600160a01b031633146108905760405162461bcd60e51b815260206004820181905260248201527f4f776e61626c653a2063616c6c6572206973206e6f7420746865206f776e65726044820152606401610509565b600a80546001600160a01b038381166001600160a01b0319831681179093556040519116919082907f8be0079c531659141344cd1fd0a4f28419497f9722a3daafe3b4186f6b6457e090600090a35050565b816001600160a01b0316836001600160a01b03161415610fda5760405162461bcd60e51b815260206004820152601960248201527f4552433732313a20617070726f766520746f2063616c6c6572000000000000006044820152606401610509565b6001600160a01b03838116600081815260056020908152604080832094871680845294825291829020805460ff191686151590811790915591519182527f17307eab39ab6107e8899845ad3d59bd9653f200f220920489ca2b5937696c31910160405180910390a3505050565b611052848484610d01565b61105e8484848461140b565b6108e25760405162461bcd60e51b815260040161050990611e11565b60608161109e5750506040805180820190915260018152600360fc1b602082015290565b8160005b81156110c857806110b281611c2a565b91506110c19050600a83611e79565b91506110a2565b60008167ffffffffffffffff8111156110e3576110e3611a51565b6040519080825280601f01601f19166020018201604052801561110d576020820181803683370190505b5090505b8415610cf957611122600183611de2565b915061112f600a86611e8d565b61113a906030611df9565b60f81b81838151811061114f5761114f611bfe565b60200101906001600160f81b031916908160001a905350611171600a86611e79565b9450611111565b606061119482600581111561118f5761118f61198c565b61107a565b6040516020016111a49190611ea1565b6040516020818303038152906040529050919050565b8051606090806111da575050604080516020810190915260008152919050565b600060036111e9836002611df9565b6111f39190611e79565b6111fe906004611eff565b9050600061120d826020611df9565b67ffffffffffffffff81111561122557611225611a51565b6040519080825280601f01601f19166020018201604052801561124f576020820181803683370190505b5090506000604051806060016040528060408152602001611f8f604091399050600181016020830160005b868110156112db576003818a01810151603f601282901c8116860151600c83901c8216870151600684901c831688015192909316870151600891821b60ff94851601821b92841692909201901b91160160e01b83526004909201910161127a565b5060038606600181146112f5576002811461130657611312565b613d3d60f01b600119830152611312565b603d60f81b6000198301525b505050918152949350505050565b6001600160a01b03831661137b5761137681600880546000838152600960205260408120829055600182018355919091527ff3f7a9fe364faab93b216da50a3214154f22a0a2b415b23a84c8169e8b636ee30155565b61139e565b816001600160a01b0316836001600160a01b03161461139e5761139e8382611509565b6001600160a01b0382166113b5576105aa816115a6565b826001600160a01b0316826001600160a01b0316146105aa576105aa8282611655565b6113e28383611699565b6113ef600084848461140b565b6105aa5760405162461bcd60e51b815260040161050990611e11565b60006001600160a01b0384163b156114fe57604051630a85bd0160e11b81526001600160a01b0385169063150b7a029061144f903390899088908890600401611f1e565b6020604051808303816000875af192505050801561148a575060408051601f3d908101601f1916820190925261148791810190611f5b565b60015b6114e4573d8080156114b8576040519150601f19603f3d011682016040523d82523d6000602084013e6114bd565b606091505b5080516114dc5760405162461bcd60e51b815260040161050990611e11565b805181602001fd5b6001600160e01b031916630a85bd0160e11b149050610cf9565b506001949350505050565b60006001611516846107f8565b6115209190611de2565b600083815260076020526040902054909150808214611573576001600160a01b03841660009081526006602090815260408083208584528252808320548484528184208190558352600790915290208190555b5060009182526007602090815260408084208490556001600160a01b039094168352600681528383209183525290812055565b6008546000906115b890600190611de2565b600083815260096020526040812054600880549394509092849081106115e0576115e0611bfe565b90600052602060002001549050806008838154811061160157611601611bfe565b600091825260208083209091019290925582815260099091526040808220849055858252812055600880548061163957611639611f78565b6001900381819060005260206000200160009055905550505050565b6000611660836107f8565b6001600160a01b039093166000908152600660209081526040808320868452825280832085905593825260079052919091209190915550565b6001600160a01b0382166116ef5760405162461bcd60e51b815260206004820181905260248201527f4552433732313a206d696e7420746f20746865207a65726f20616464726573736044820152606401610509565b6000818152600260205260409020546001600160a01b0316156117545760405162461bcd60e51b815260206004820152601c60248201527f4552433732313a20746f6b656e20616c7265616479206d696e746564000000006044820152606401610509565b61176060008383611320565b6000818152600260205260409020546001600160a01b0316156117c55760405162461bcd60e51b815260206004820152601c60248201527f4552433732313a20746f6b656e20616c7265616479206d696e746564000000006044820152606401610509565b6001600160a01b03821660009081526003602052604081208054600192906117ee908490611df9565b909155505060008181526002602052604080822080546001600160a01b0319166001600160a01b03861690811790915590518392907fddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef908290a45050565b6001600160e01b031981168114610b6257600080fd5b60006020828403121561187457600080fd5b813561187f8161184c565b9392505050565b60005b838110156118a1578181015183820152602001611889565b838111156108e25750506000910152565b600081518084526118ca816020860160208601611886565b601f01601f19169290920160200192915050565b60208152600061187f60208301846118b2565b60006020828403121561190357600080fd5b5035919050565b80356001600160a01b038116811461192157600080fd5b919050565b6000806040838503121561193957600080fd5b6119428361190a565b946020939093013593505050565b60008060006060848603121561196557600080fd5b61196e8461190a565b925061197c6020850161190a565b9150604084013590509250925092565b634e487b7160e01b600052602160045260246000fd5b60208101600683106119c457634e487b7160e01b600052602160045260246000fd5b91905290565b600080604083850312156119dd57600080fd5b6119e68361190a565b91506020830135600681106119fa57600080fd5b809150509250929050565b600060208284031215611a1757600080fd5b61187f8261190a565b60008060408385031215611a3357600080fd5b611a3c8361190a565b9150602083013580151581146119fa57600080fd5b634e487b7160e01b600052604160045260246000fd5b60008060008060808587031215611a7d57600080fd5b611a868561190a565b9350611a946020860161190a565b925060408501359150606085013567ffffffffffffffff80821115611ab857600080fd5b818701915087601f830112611acc57600080fd5b813581811115611ade57611ade611a51565b604051601f8201601f19908116603f01168101908382118183101715611b0657611b06611a51565b816040528281528a6020848701011115611b1f57600080fd5b82602086016020830137600060208483010152809550505050505092959194509250565b60008060408385031215611b5657600080fd5b611b5f8361190a565b9150611b6d6020840161190a565b90509250929050565b600181811c90821680611b8a57607f821691505b60208210811415611bab57634e487b7160e01b600052602260045260246000fd5b50919050565b6020808252602d908201527f4552433732313a2063616c6c6572206973206e6f7420746f6b656e206f776e6560408201526c1c881bdc88185c1c1c9bdd9959609a1b606082015260800190565b634e487b7160e01b600052603260045260246000fd5b634e487b7160e01b600052601160045260246000fd5b6000600019821415611c3e57611c3e611c14565b5060010190565b6f7b226e616d65223a202252756e65202360801b81528251600090611c71816010850160208801611886565b61088b60f21b601091840191820152750899195cd8dc9a5c1d1a5bdb888e8808949d5b99488b60521b60128201527f22696d616765223a202268747470733a2f2f6578616d706c652e636f6d2f6e6f6028820152661d0b5cd95d088b60ca1b60488201527f2265787465726e616c5f75726c223a202268747470733a2f2f6578616d706c65604f8201526d0b98dbdb4bdb9bdd0b5cd95d088b60921b606f8201526e2261747472696275746573223a205b60881b607d8201528351611d3d81608c840160208801611886565b615d7d60f01b608c9290910191820152608e01949350505050565b7f646174613a6170706c69636174696f6e2f6a736f6e3b6261736536342c000000815260008251611d9081601d850160208701611886565b91909101601d0192915050565b60208082526025908201527f4552433732313a207472616e736665722066726f6d20696e636f72726563742060408201526437bbb732b960d91b606082015260800190565b600082821015611df457611df4611c14565b500390565b60008219821115611e0c57611e0c611c14565b500190565b60208082526032908201527f4552433732313a207472616e7366657220746f206e6f6e20455243373231526560408201527131b2b4bb32b91034b6b83632b6b2b73a32b960711b606082015260800190565b634e487b7160e01b600052601260045260246000fd5b600082611e8857611e88611e63565b500490565b600082611e9c57611e9c611e63565b500690565b7f7b2274726169745f74797065223a2022416c69676e6d656e74222c202276616c81526403ab2911d160dd1b602082015260008251611ee7816025850160208701611886565b607d60f81b6025939091019283015250602601919050565b6000816000190483118215151615611f1957611f19611c14565b500290565b6001600160a01b0385811682528416602082015260408101839052608060608201819052600090611f51908301846118b2565b9695505050505050565b600060208284031215611f6d57600080fd5b815161187f8161184c565b634e487b7160e01b600052603160045260246000fdfe4142434445464748494a4b4c4d4e4f505152535455565758595a6162636465666768696a6b6c6d6e6f707172737475767778797a303132333435363738392b2fa2646970667358221220f74712f69651d4ba404e2ba5a45d2e19411a253d3ad81f6f35be077c897573c264736f6c634300080b0033";

type RuneConstructorParams =
  | [signer?: Signer]
  | ConstructorParameters<typeof ContractFactory>;

const isSuperArgs = (
  xs: RuneConstructorParams
): xs is ConstructorParameters<typeof ContractFactory> => xs.length > 1;

export class Rune__factory extends ContractFactory {
  constructor(...args: RuneConstructorParams) {
    if (isSuperArgs(args)) {
      super(...args);
    } else {
      super(_abi, _bytecode, args[0]);
    }
  }

  override deploy(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): Promise<Rune> {
    return super.deploy(overrides || {}) as Promise<Rune>;
  }
  override getDeployTransaction(
    overrides?: Overrides & { from?: PromiseOrValue<string> }
  ): TransactionRequest {
    return super.getDeployTransaction(overrides || {});
  }
  override attach(address: string): Rune {
    return super.attach(address) as Rune;
  }
  override connect(signer: Signer): Rune__factory {
    return super.connect(signer) as Rune__factory;
  }

  static readonly bytecode = _bytecode;
  static readonly abi = _abi;
  static createInterface(): RuneInterface {
    return new utils.Interface(_abi) as RuneInterface;
  }
  static connect(address: string, signerOrProvider: Signer | Provider): Rune {
    return new Contract(address, _abi, signerOrProvider) as Rune;
  }
}
