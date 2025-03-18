import { describe, expect, it } from "vitest";
import { Cl } from "@stacks/transactions";

const accounts = simnet.getAccounts();
const creator = accounts.get("wallet_1")!;
const other = accounts.get("wallet_2")!;

describe("IP Protection", () => {
    it("successfully registers a new work", () => {
        // Sample hash of a work (32 bytes)
        const workHash = "0x000102030405060708090a0b0c0d0e0f000102030405060708090a0b0c0d0e0f";
        const title = "My Artwork";
        const description = "A beautiful digital painting";

        const registerCall = simnet.callPublicFn(
            "protection",
            "register-work",
            [
                Cl.bufferFromHex(workHash.substring(2)),
                Cl.stringUtf8(title),
                Cl.stringUtf8(description)
            ],
            creator
        );
        expect(registerCall.result).toBeOk(Cl.bool(true));
    });

 

    it("verifies incorrect ownership", () => {
        const workHash = "0x000102030405060708090a0b0c0d0e0f000102030405060708090a0b0c0d0e0f";
        
        const verifyCall = simnet.callReadOnlyFn(
            "protection",
            "verify-ownership",
            [
                Cl.bufferFromHex(workHash.substring(2)),
                Cl.principal(creator)
            ],
            creator
        );
        expect(verifyCall.result).toBeErr(Cl.uint(2));
    });
});
