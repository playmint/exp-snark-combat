import { Contract } from "ethers";

export type HitPointOption = "default" | "weak" | "weakest";
export type HitPoints = Map<HitPointOption, [number, number, number, number, number, number, number, number]>;

export async function simpleVarCheckValue(contract: Contract, getter: string, setter: string, value: any) {
    const current = await contract[getter]();
    if (current.toString() != value.toString()) {
        console.log(getter, "returned", current, "updating to", value);
        await (await contract[setter](value)).wait();
    } else {
        console.log(getter, "already set to", value);
    }
}

export async function mapVarCheckValue(contract: Contract, getter: string, key: number, setter: string, o: any) {
    const current = await contract[getter](key);
    if (current.toString() != o[key].toString()) {
        console.log(`${getter}[${key}] returned ${current} updating to ${o[key]}`);
        await (await contract[setter](key, o[key])).wait();
    } else {
        console.log(`${getter}[${key}] already set to ${o[key]}`);
    }
}
