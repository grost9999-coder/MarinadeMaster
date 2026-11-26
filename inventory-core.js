(function(root){
  "use strict";
  function toUnit(q,from,to){
    if(!Number.isFinite(+q))return null;
    if(from===to)return +q;
    if(from==="g"&&to==="kg")return +q/1000;
    if(from==="kg"&&to==="g")return +q*1000;
    return null;
  }
  function weightedAverage(oldQty,oldPrice,inQty,inPrice){
    if([oldQty,oldPrice,inQty,inPrice].some(x=>!Number.isFinite(+x))||oldQty<0||inQty<=0||oldPrice<0||inPrice<0)throw new Error("Invalid stock or purchase values");
    const total=oldQty+inQty;
    if(total<=0)throw new Error("Total stock must be positive");
    return (oldQty*oldPrice+inQty*inPrice)/total;
  }
  function captureCosts(groups,stock){
    const snap={};
    for(const group of groups||[])for(const item of group.items||[]){
      const name=item[0],s=(stock||[]).find(x=>x.name===name);
      if(s&&Number.isFinite(+s.price)&&s.price>=0)snap[name]={unit:s.unit,price:+s.price};else snap[name]={missing:true};
    }
    return snap;
  }
  function calculateCost(groups,stock,snapshot){
    let total=0;const missing=[];
    for(const group of groups||[])for(const item of group.items||[]){
      const [name,qty,unit]=item;
      const current=(stock||[]).find(x=>x.name===name);
      const hasSnapshot=!!(snapshot&&Object.prototype.hasOwnProperty.call(snapshot,name));
      const chosen=hasSnapshot?snapshot[name]:current;
      if(!chosen||chosen.missing||!Number.isFinite(+chosen.price)||+chosen.price<0||!["g","kg"].includes(chosen.unit)){missing.push(name);continue;}
      const amount=toUnit(+qty,unit,chosen.unit);
      if(amount===null){missing.push(name);continue;}
      total+=amount*(+chosen.price);
    }
    return {total,missing:[...new Set(missing)],complete:missing.length===0};
  }
  function applyPurchase(stock,purchase){
    if(!purchase||!purchase.name||!["g","kg"].includes(purchase.unit)||!(purchase.qty>0)||!(purchase.unitPrice>=0))throw new Error("Invalid purchase");
    let item=stock.find(x=>x.name===purchase.name);
    if(!item){item={name:purchase.name,unit:purchase.unit,qty:0,price:0};stock.push(item);}
    if(item.unit!==purchase.unit)throw new Error("Purchase unit must match the ingredient stock unit");
    item.price=weightedAverage(+item.qty||0,+item.price||0,+purchase.qty,+purchase.unitPrice);
    item.qty=(+item.qty||0)+purchase.qty;
    return item;
  }
  function aggregateRequirements(groups,stock){
    const totals={};
    for(const group of groups||[])for(const item of group.items||[]){
      const name=item[0],row=(stock||[]).find(x=>x.name===name);
      const amount=row?toUnit(+item[1],item[2],row.unit):null;
      if(amount===null){totals[name]=null;continue;}
      if(totals[name]!==null)totals[name]=(totals[name]||0)+amount;
    }
    return totals;
  }
  function consumeStock(stock,name,qty,unit){
    const item=stock.find(x=>x.name===name);
    if(!item)throw new Error("Missing stock: "+name);
    const amount=toUnit(qty,unit,item.unit);
    if(amount===null||amount<0||item.qty+1e-9<amount)throw new Error("Insufficient stock: "+name);
    item.qty=Math.max(0,item.qty-amount);
    return item;
  }

  function returnPurchase(stock,purchase,qty){
    const remaining=+purchase.qty-(+purchase.returnedQty||0);
    if(!Number.isFinite(qty)||qty<=0||qty>remaining+1e-9)throw new Error("Return quantity exceeds the unreturned purchase quantity");
    const item=stock.find(x=>x.name===purchase.name);
    if(!item||item.unit!==purchase.unit||item.qty+1e-9<qty)throw new Error("Insufficient stock for this purchase return");
    const oldQty=+item.qty,oldValue=oldQty*(+item.price||0),returnValue=qty*(+purchase.unitPrice);
    const nextQty=Math.max(0,oldQty-qty);
    item.qty=nextQty;
    item.price=nextQty>1e-9?Math.max(0,(oldValue-returnValue)/nextQty):0;
    purchase.returnedQty=(+purchase.returnedQty||0)+qty;
    return {item,returnedQty:qty,remainingQty:Math.max(0,+purchase.qty-purchase.returnedQty)};
  }
  function adjustStock(stock,name,countedQty){
    const item=stock.find(x=>x.name===name);
    if(!item)throw new Error("Missing stock: "+name);
    if(!Number.isFinite(countedQty)||countedQty<0)throw new Error("Counted stock must be a non-negative number");
    const before=+item.qty||0,delta=countedQty-before;
    item.qty=countedQty;
    return {item,before,after:countedQty,delta};
  }
  function validateBackup(input){
    let data;
    try{data=JSON.parse(JSON.stringify(input));}catch(e){throw new Error("Backup is not valid JSON data");}
    if(!data||!Array.isArray(data.recipes)||!Array.isArray(data.batches)||!Array.isArray(data.stock))throw new Error("Backup must contain recipes, batches and stock arrays");
    data.ledger=Array.isArray(data.ledger)?data.ledger:[];
    data.purchases=Array.isArray(data.purchases)?data.purchases:[];
    for(const s of data.stock){if(!s||typeof s.name!=="string"||!s.name.trim()||!["g","kg"].includes(s.unit)||!Number.isFinite(+s.qty)||+s.qty<0||!Number.isFinite(+s.price)||+s.price<0)throw new Error("Backup contains invalid stock records");}
    for(const p of data.purchases){if(!p||typeof p.name!=="string"||!["g","kg"].includes(p.unit)||!Number.isFinite(+p.qty)||+p.qty<=0||!Number.isFinite(+p.unitPrice)||+p.unitPrice<0)throw new Error("Backup contains invalid purchase records");p.returnedQty=Number.isFinite(+p.returnedQty)?+p.returnedQty:0;}
    return data;
  }
  root.InventoryCore={toUnit,weightedAverage,captureCosts,calculateCost,applyPurchase,consumeStock,aggregateRequirements,returnPurchase,adjustStock,validateBackup};
  if(typeof module!=="undefined"&&module.exports)module.exports=root.InventoryCore;
})(typeof globalThis!=="undefined"?globalThis:this);
