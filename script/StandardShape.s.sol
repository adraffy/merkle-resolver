pragma solidity ^0.8.23;

import {Script, console2} from "forge-std/Script.sol";
import {MerkleResolver} from "../src/MerkleResolver.sol";

contract StandardShape is Script {

	function run() public {
		bytes32[] memory cells = new bytes32[](32);
		uint256 n;
		MerkleResolver r = new MerkleResolver();
		cells[n++] = r.CELL_CONTENTHASH();
		cells[n++] = r.cellForAddr(60);
		cells[n++] = r.cellForAddr(8444);
		cells[n++] = r.cellForText("avatar");
		cells[n++] = r.cellForText("description");
		cells[n++] = r.cellForText("url");
		cells[n++] = r.cellForText("notice");
		assembly { mstore(cells, n) }
		bytes32 shape = r.createShape(cells);
		console2.logBytes32(shape);
		for (uint256 i = 0; i < n; i++) {
			console2.logBytes32(cells[i]);
		}
	}
}
