/// @author raffy.eth
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IERC165} from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import {ENS} from "@ensdomains/ens-contracts/contracts/registry/ENS.sol";
import {IAddrResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IAddrResolver.sol";
import {IAddressResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IAddressResolver.sol";
import {ITextResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/ITextResolver.sol";
import {IContentHashResolver} from "@ensdomains/ens-contracts/contracts/resolvers/profiles/IContentHashResolver.sol";

contract MerkleResolver is
	IERC165,
	IAddrResolver,
	IAddressResolver,
	ITextResolver,
	IContentHashResolver
{
	function supportsInterface(bytes4 x) external pure returns (bool) {
		return
			x == type(IERC165).interfaceId            || // 0x01ffc9a7
			x == type(IAddrResolver).interfaceId      || // 0x3b3b57de
			x == type(IAddressResolver).interfaceId   || // 0xf1cb7e06
			x == type(ITextResolver).interfaceId      || // 0x59d1d43c
			x == type(IContentHashResolver).interfaceId; // 0xbc1c58d1
	}

	event Invalidated(bytes32 indexed node);
	event NewProof(bytes32 indexed node, bytes32 root);
	event NewShape(bytes32 shape, bytes32[] indexed cells);

	address constant ENS_REGISTRY = 0x00000000000C2E074eC69A0dFb2997BA6C7d2e1e;
	uint256 constant COIN_TYPE_ETH = 60;

	bytes32 public constant CELL_CONTENTHASH =
		hex"e7a4d58292e7d1cf5c961b77ba8508ed6ec28912b9903cef7db123b76ac271";

	function cellForAddr(uint256 coinType) public pure returns (bytes32) {
		return keccak256(abi.encode("addr", coinType));
	}

	function cellForText(string memory key) public pure returns (bytes32) {
		return keccak256(abi.encode("text", key));
	}

	function bitLength(uint256 size) internal pure returns (uint256 n) {
		unchecked {
			while (size > 0) {
				n += 1;
				size >>= 1;
			}
		}
	}

	mapping(bytes32 => uint256) _size;
	mapping(bytes32 => bytes32) _shape;
	mapping(bytes32 => bytes32) _root;
	mapping(bytes => uint256) _slot;
	mapping(bytes => bytes) _value;

	function requireApproval(bytes32 node) internal view {
		//address owner = ENS(ENS_REGISTRY).owner(node);
		//require(owner == msg.sender || ENS(ENS_REGISTRY).isApprovedForAll(owner, msg.sender), "approval");
	}

	function createShape(bytes32[] memory cells) public returns (bytes32) {
		require(cells.length > 0, "empty");
		bytes32 shape;
		for (uint256 i; i < cells.length; i += 1) {
			bytes32 cell = cells[i];
			shape = keccak256(abi.encode(shape, cell));
			for (uint256 j = i + 1; j < cells.length; j += 1) {
				require(cell != cells[j], "duplicate");
			}
		}
		uint256 size0 = _size[shape];
		if (size0 > 0) {
			require(size0 == cells.length, "wtf");
		} else {
			_size[shape] = cells.length;
			for (uint256 i; i < cells.length; i++) {
				_slot[abi.encode(shape, cells[i])] = i + 1;
			}
			emit NewShape(shape, cells);
		}
		return shape;
	}

	function setShape(bytes32 node, bytes32 shape) public {
		uint256 size = _size[shape];
		require(size > 0, "bad shape");
		_shape[node] = shape;
		_root[node] = 0;
		uint256 capacity = 1 << bitLength(size);
		for (uint256 i = size; i < capacity; i += 1) {
			_value[abi.encode(node, i)] = "";
		}
	}

	function _findShape(bytes32 node)
		internal
		view
		returns (bytes32 shape, uint256 size)
	{
		shape = _shape[node];
		size = _size[shape];
		require(size > 0, "no shape");
	}

	function _findSlot(bytes32 node, bytes32 cell)
		internal
		view
		returns (uint256 slot)
	{
		(bytes32 shape, uint256 size) = _findShape(node);
		slot = _slot[abi.encode(shape, cell)];
		require(slot <= size, "bad cell");
	}

	function get(bytes32 node, bytes32 cell)
		public
		view
		returns (bytes memory value)
	{
		uint256 slot = _findSlot(node, cell);
		if (slot > 0) {
			value = _value[abi.encode(node, slot - 1)];
		}
	}

	function set(
		bytes32 node,
		bytes32 cell,
		bytes memory value
	) public {
		requireApproval(node);
		uint256 slot = _findSlot(node, cell);
		require(slot > 0, "bad cell");
		_value[abi.encode(node, slot - 1)] = value;
		_root[node] = 0;
		emit Invalidated(node);
	}

	function _hashPair(bytes32 a, bytes32 b) internal pure returns (bytes32) {
		return
			uint256(a) < uint256(b)
				? keccak256(abi.encode(a, b))
				: keccak256(abi.encode(b, a));
	}

	function _makeProof(bytes32 node, uint256 size)
		private
		view
		returns (bytes32)
	{
		uint256 capacity = 1 << bitLength(size);
		bytes32[] memory hashes = new bytes32[](capacity >> 1);
		for (uint256 i; i < capacity; i += 2) {
			hashes[i >> 1] = _hashPair(
				keccak256(_value[abi.encode(node, i)]),
				keccak256(_value[abi.encode(node, i + 1)])
			);
		}
		capacity >>= 1;
		while (capacity > 1) {
			for (uint256 i; i < capacity; i += 2) {
				hashes[i >> 1] = _hashPair(hashes[i], hashes[i + 1]);
			}
			capacity >>= 1;
		}
		return hashes[0];
	}

	function commit(bytes32 node) public returns (bytes32 root) {
		requireApproval(node);
		(, uint256 size) = _findShape(node);
		_root[node] = root = _makeProof(node, size);
		emit NewProof(node, root);
	}

	function getProof(bytes32 node)
		public
		view
		returns (bytes32 root, bytes32[] memory hashes)
	{
		(, uint256 size) = _findShape(node);
		root = _root[node];
		hashes = new bytes32[](size);
		for (uint256 i; i < size; i += 1) {
			hashes[i] = keccak256(_value[abi.encode(node, i)]);
		}
	}

	// getters
	function addr(bytes32 node) external view returns (address payable ret) {
		bytes memory v = get(node, cellForAddr(60));
		if (v.length > 0) {
			require(v.length == 20);
			ret = payable(address(bytes20(v)));
		}
	}

	function addr(bytes32 node, uint256 coinType)
		external
		view
		returns (bytes memory)
	{
		return get(node, cellForAddr(coinType));
	}

	function text(bytes32 node, string memory key)
		external
		view
		returns (string memory)
	{
		return string(get(node, cellForText(key)));
	}

	function contenthash(bytes32 node) external view returns (bytes memory) {
		return get(node, CELL_CONTENTHASH);
	}

	// setters
	function setAddr(bytes32 node, address a) public {
		setAddr(node, COIN_TYPE_ETH, abi.encodePacked(a));
	}

	function setAddr(
		bytes32 node,
		uint256 coinType,
		bytes memory v
	) public {
		if (coinType == COIN_TYPE_ETH) {
			require(v.length == 20 || v.length == 0);
			emit IAddrResolver.AddrChanged(node, address(bytes20(v)));
		}
		set(node, cellForAddr(coinType), v);
		emit IAddressResolver.AddressChanged(node, coinType, v);
	}

	function setText(
		bytes32 node,
		string memory key,
		string memory s
	) public {
		set(node, cellForText(key), bytes(s));
		emit ITextResolver.TextChanged(node, key, key, s);
	}

	function setContenthash(bytes32 node, bytes memory v) public {
		set(node, CELL_CONTENTHASH, v);
		emit IContentHashResolver.ContenthashChanged(node, v);
	}
}
