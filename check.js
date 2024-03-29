import {ethers} from 'ethers';

const EMPTY_HASH = ethers.keccak256('0x');

// let node = '0x0000000000000000000000000000000000000000000000000000000000001234';
// let root = '0x6e84ff5d0bea1bfa5739ec39ccb267ba92641a7c80b5eb2198dc5b19456ed61a';
// let hashes = [
// 	'0x56570de287d73cd1cb6092bb8fdee6173974955fdef345ae579ee9f475ea7432',
// 	'0x7feee1d19a60bcdfb43be154142382399a2fcf31455099331af941304e71798d',
// 	'0xb54922573c27697c1a45fbdb04f41f3730976a59486c4ede520802964d3ca8ab'
// ];

let node = '0x3c0155c0a484a249aa230f22fa71350191e9950c56337dc7d85b9e265ef243da';
let root = '0x3638c4f038e5d7f9883af8adf3c16ea77443ea9fa36423a32cf429c9b115dd0a';
let hashes = '0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470,0x7feee1d19a60bcdfb43be154142382399a2fcf31455099331af941304e71798d,0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470,0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470,0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470,0x4440fb9330ea12add4c4a59a24ae1b457e4a03e8fdabeb21b239fba5803999df,0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470'.split(',');

console.log(root);
console.log(get_proof(hashes));

function get_proof(hashes) {
	let v = hashes.slice();
	let n = 1 << Math.ceil(Math.log2(v.length));
	while (v.length < n) v.push(EMPTY_HASH);
	while (v.length > 1) {
		let u = [];
		for (let i = 0; i < v.length; i += 2) {
			let a = v[i]   ?? ethEMPTY_HASH;
			let b = v[i+1] ?? EMPTY_HASH;
			u.push(ethers.keccak256(ethers.concat([a, b].sort((a, b) => BigInt(a) < BigInt(b) ? -1 : 1))));
		}
		v = u;
	}
	return v[0];
}
