
describe('Report', async function () {
    it('should generate report', () => {


        const vars = variants()
        console.log(vars);
        console.log(`there are ${vars.length} variants`);


    });
});

interface Variant {
    name: string;
    seekers: number;
    ticks: number;
    actions: number;
    isChainStorage: boolean;
    isChainCalc: boolean;
}

function variants():Variant[] {
    const nSeekers = [1,2,4,8,16,32,64,128,256,512];
    const nTicks = [10,20,40,80,160,320,640];
    const nActions = [1,2,4,8];
    const chainStorage = [true, false];
    const chainCalc = [true, false];

    const variants:Variant[] = [];
    nSeekers.forEach((seekers) => {
        nTicks.forEach((ticks) => {
            nActions.forEach((actions) => {
                chainStorage.forEach((isChainStorage) => {
                    chainCalc.forEach((isChainCalc) => {
                        const name = `${isChainStorage ? 'OnChainStorage' : 'OffChainStorage'}_${isChainCalc ? 'OnChainCalc' : 'OffChainCalc'}_s${seekers}_t${ticks}_a${actions}`;
                        const variant = {
                            seekers,
                            ticks,
                            actions,
                            isChainStorage,
                            isChainCalc,
                            name,
                        };
                        variants.push(variant);
                        console.log(variant);
                    });
                });
            });
        });
    }, []);

    return variants;
}
