pragma solidity ^0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {MerkleResolver} from "../src/MerkleResolver.sol";

contract Play is Script {
    
	MerkleResolver internal r;

	function setUp() public {
		r = new MerkleResolver();
	}
	
    function run() public {
		bytes32[] memory cells = new bytes32[](3);
		cells[0] = r.CELL_CONTENTHASH();
		cells[1] = r.cellForAddr(60);
		cells[2] = r.cellForText("avatar");
		bytes32 shape = r.createShape(cells);
		bytes32 node = bytes32(uint256(0x1234));
		r.setShape(node, shape);
		r.setText(node, "avatar", "chonk");
		r.setAddr(node, 0x51050ec063d393217B436747617aD1C2285Aeeee);
		r.setContenthash(node, hex"1234");
		r.commit(node);

		(bytes32 root, bytes32[] memory hashes) = r.getProof(node);
		console2.logBytes32(root);
		for (uint256 i = 0; i < hashes.length; i++) {
			console2.logBytes32(hashes[i]);
		}

    }
}
