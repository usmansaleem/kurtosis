// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

contract PrecompileCaller {
    // --- Generic raw caller (handy for ad-hoc tests) ---
    function callRaw(address pc, bytes calldata data) external returns (bytes memory out) {
        (bool ok, bytes memory ret) = pc.staticcall(data);
        require(ok, "precompile failed");
        return ret;
    }

    // 0x01: ecrecover(hash, v, r, s) -> 32 bytes (address right-padded)
    function callECRecover(bytes32 hash, uint8 v, bytes32 r, bytes32 s)
        external
        returns (bytes memory out)
    {
        // EIP-196 spec: input = [hash(32) | v(32) | r(32) | s(32)], v in [27,28] or EIP-155 style
        bytes memory payload =
            abi.encodePacked(hash, bytes32(uint256(v)), r, s);
        (bool ok, bytes memory ret) = address(0x01).staticcall(payload);
        require(ok, "ecrecover failed");
        return ret;
    }

    // 0x02: sha256(data) -> 32 bytes
    function callSHA256(bytes calldata data) external returns (bytes memory) {
        (bool ok, bytes memory ret) = address(0x02).staticcall(data);
        require(ok, "sha256 failed");
        return ret;
    }

    // 0x03: ripemd160(data) -> 32 bytes (20-byte digest left-padded with zeros to 32)
    function callRIPEMD160(bytes calldata data) external returns (bytes memory) {
        (bool ok, bytes memory ret) = address(0x03).staticcall(data);
        require(ok, "ripemd160 failed");
        return ret;
    }

    // 0x04: identity(data) -> data
    function callIdentity(bytes calldata data) external returns (bytes memory) {
        (bool ok, bytes memory ret) = address(0x04).staticcall(data);
        require(ok, "identity failed");
        return ret;
    }

    // 0x05: modexp per EIP-198
    // input = [len(base)(32) | len(exp)(32) | len(mod)(32) | base | exp | mod]
    function callModExp(bytes calldata base, bytes calldata exp, bytes calldata mod_)
        external
        returns (bytes memory)
    {
        bytes memory payload = abi.encodePacked(
            bytes32(base.length), bytes32(exp.length), bytes32(mod_.length),
            base, exp, mod_
        );
        (bool ok, bytes memory ret) = address(0x05).staticcall(payload);
        require(ok, "modexp failed");
        return ret;
    }

    // 0x06: bn128Add((x1,y1),(x2,y2)) -> (x3,y3) 64 bytes
    function callBn128Add(bytes32 x1, bytes32 y1, bytes32 x2, bytes32 y2)
        external
        returns (bytes memory)
    {
        bytes memory payload = abi.encodePacked(x1, y1, x2, y2);
        (bool ok, bytes memory ret) = address(0x06).staticcall(payload);
        require(ok, "bn128 add failed");
        return ret;
    }

    // 0x07: bn128Mul((x,y), scalar) -> (x2,y2) 64 bytes
    function callBn128Mul(bytes32 x, bytes32 y, bytes32 scalar)
        external
        returns (bytes memory)
    {
        bytes memory payload = abi.encodePacked(x, y, scalar);
        (bool ok, bytes memory ret) = address(0x07).staticcall(payload);
        require(ok, "bn128 mul failed");
        return ret;
    }

    // 0x08: bn128Pairing(pairs) -> 32 bytes (0/1). Each pair is 192 bytes:
    // G1(x,y) (2*32) + G2(x_im, x_re, y_im, y_re) (4*32). Use empty payload to get "1".
    function callBn128Pairing(bytes calldata pairs)
        external
        returns (bytes memory)
    {
        (bool ok, bytes memory ret) = address(0x08).staticcall(pairs);
        require(ok, "bn128 pairing failed");
        return ret;
    }

    // 0x09: blake2f(rounds,h,m,t,final) -> 64 bytes state. Input length must be exactly 213 bytes.
    // rounds: uint32 big-endian; h: 64B; m: 128B; t: 16B; final: 1B (0x00 or 0x01)
    function callBlake2F(bytes calldata input213)
        external
        returns (bytes memory)
    {
        require(input213.length == 213, "blake2f bad len");
        (bool ok, bytes memory ret) = address(0x09).staticcall(input213);
        require(ok, "blake2f failed");
        return ret;
    }

    // 0x0a: KZG point evaluation (Cancun/Deneb). Kept generic — supply proper blob per EIP-4844.
    function callKZG(bytes calldata input)
        external
        returns (bytes memory)
    {
        (bool ok, bytes memory ret) = address(0x0a).staticcall(input);
        require(ok, "kzg failed");
        return ret;
    }
}
