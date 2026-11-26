const test=require("node:test");
const assert=require("node:assert/strict");
const core=require("../inventory-core.js");
test("g/kg conversion is precise",()=>{assert.equal(core.toUnit(1500,"g","kg"),1.5);assert.equal(core.toUnit(2,"kg","g"),2000);});
test("weighted average preserves old purchase cost",()=>{assert.equal(core.weightedAverage(100,80,100,100),90);});
test("purchase creates stock and weighted average",()=>{const stock=[{name:"雞肉",unit:"kg",qty:10,price:80}];const row=core.applyPurchase(stock,{name:"雞肉",unit:"kg",qty:10,unitPrice:100});assert.equal(row.qty,20);assert.equal(row.price,90);});
test("batch cost uses captured historical prices",()=>{const groups=[{items:[["鹽",500,"g"]]}],stock=[{name:"鹽",unit:"kg",qty:4,price:120}],snap={鹽:{unit:"kg",price:80}};assert.equal(core.calculateCost(groups,stock,snap).total,40);});
test("insufficient stock cannot be consumed",()=>{const stock=[{name:"粉",unit:"kg",qty:0.2,price:30}];assert.throws(()=>core.consumeStock(stock,"粉",300,"g"),/Insufficient/);assert.equal(stock[0].qty,0.2);});
test("missing prices are flagged, never guessed",()=>{const result=core.calculateCost([{items:[["未知料",10,"g"]]}],[],{});assert.equal(result.complete,false);assert.deepEqual(result.missing,["未知料"]);});
