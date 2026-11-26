const test=require("node:test");
const assert=require("node:assert/strict");
const core=require("../inventory-core.js");
test("g/kg conversion is precise",()=>{assert.equal(core.toUnit(1500,"g","kg"),1.5);assert.equal(core.toUnit(2,"kg","g"),2000);});
test("weighted average preserves old purchase cost",()=>{assert.equal(core.weightedAverage(100,80,100,100),90);});
test("purchase creates stock and weighted average",()=>{const stock=[{name:"雞肉",unit:"kg",qty:10,price:80}];const row=core.applyPurchase(stock,{name:"雞肉",unit:"kg",qty:10,unitPrice:100});assert.equal(row.qty,20);assert.equal(row.price,90);});
test("batch cost uses captured historical prices",()=>{const groups=[{items:[["鹽",500,"g"]]}],stock=[{name:"鹽",unit:"kg",qty:4,price:120}],snap={鹽:{unit:"kg",price:80}};assert.equal(core.calculateCost(groups,stock,snap).total,40);});
test("insufficient stock cannot be consumed",()=>{const stock=[{name:"粉",unit:"kg",qty:0.2,price:30}];assert.throws(()=>core.consumeStock(stock,"粉",300,"g"),/Insufficient/);assert.equal(stock[0].qty,0.2);});
test("missing prices are flagged, never guessed",()=>{const result=core.calculateCost([{items:[["未知料",10,"g"]]}],[],{});assert.equal(result.complete,false);assert.deepEqual(result.missing,["未知料"]);});

test("missing cost stays missing even if a later price appears",()=>{const groups=[{items:[["未知料",10,"g"]]}];const snap=core.captureCosts(groups,[]);const later=[{name:"未知料",unit:"kg",qty:1,price:50}];const result=core.calculateCost(groups,later,snap);assert.equal(result.complete,false);assert.deepEqual(result.missing,["未知料"]);});
test("zero-price purchase is rejected so unknown costs are not treated as free",()=>{const stock=[];assert.throws(()=>core.applyPurchase(stock,{name:"贈品",unit:"kg",qty:1,unitPrice:0}),/Invalid purchase/);assert.equal(core.calculateCost([{items:[["贈品",1000,"g"]]}],[{name:"贈品",unit:"kg",qty:1,price:0}]).complete,false);});

test("duplicate recipe lines are aggregated before stock deduction",()=>{const groups=[{items:[["粉",300,"g"],["粉",250,"g"]]}];const stock=[{name:"粉",unit:"kg",qty:0.6,price:20}];const totals=core.aggregateRequirements(groups,stock);assert.equal(totals["粉"],0.55);assert.ok(Math.abs(core.consumeStock(stock,"粉",totals["粉"],"kg").qty-0.05)<1e-9);});
test("aggregate requirements flags missing stock",()=>{const totals=core.aggregateRequirements([{items:[["缺料",10,"g"]]}],[]);assert.equal(totals["缺料"],null);});

test("purchase return reduces quantity and weighted value at original price",()=>{const stock=[{name:"油",unit:"kg",qty:10,price:90}],purchase={name:"油",unit:"kg",qty:5,unitPrice:100,returnedQty:0};const result=core.returnPurchase(stock,purchase,2);assert.equal(result.item.qty,8);assert.equal(result.item.price,90);assert.equal(result.inventoryValue,180);assert.equal(purchase.returnedQty,2);});
test("purchase return cannot exceed remaining purchase or available stock",()=>{const stock=[{name:"油",unit:"kg",qty:1,price:90}],purchase={name:"油",unit:"kg",qty:2,unitPrice:100,returnedQty:0};assert.throws(()=>core.returnPurchase(stock,purchase,1.5),/Insufficient stock/);assert.throws(()=>core.returnPurchase(stock,purchase,2.1),/exceeds/);});
test("stocktake writes the physical count without changing average price",()=>{const stock=[{name:"粉",unit:"kg",qty:5,price:42}];const result=core.adjustStock(stock,"粉",3.5);assert.equal(result.delta,-1.5);assert.equal(stock[0].qty,3.5);assert.equal(stock[0].price,42);});
test("backup validation upgrades older backups and rejects invalid stock",()=>{const upgraded=core.validateBackup({recipes:[],batches:[],stock:[]});assert.deepEqual(upgraded.ledger,[]);assert.deepEqual(upgraded.purchases,[]);assert.throws(()=>core.validateBackup({recipes:[],batches:[],stock:[{name:"x",unit:"lb",qty:2,price:3}]}),/invalid stock/);});
