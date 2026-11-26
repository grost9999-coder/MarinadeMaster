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
      if(s&&Number.isFinite(+s.price)&&s.price>=0)snap[name]={unit:s.unit,price:+s.price};
    }
    return snap;
  }
  function calculateCost(groups,stock,snapshot){
    let total=0;const missing=[];
    for(const group of groups||[])for(const item of group.items||[]){
      const [name,qty,unit]=item;
      const current=(stock||[]).find(x=>x.name===name);
      const chosen=snapshot&&snapshot[name]?snapshot[name]:current;
      if(!chosen||!(+chosen.price>0)||!["g","kg"].includes(chosen.unit)){missing.push(name);continue;}
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
  function consumeStock(stock,name,qty,unit){
    const item=stock.find(x=>x.name===name);
    if(!item)throw new Error("Missing stock: "+name);
    const amount=toUnit(qty,unit,item.unit);
    if(amount===null||amount<0||item.qty+1e-9<amount)throw new Error("Insufficient stock: "+name);
    item.qty=Math.max(0,item.qty-amount);
    return item;
  }
  root.InventoryCore={toUnit,weightedAverage,captureCosts,calculateCost,applyPurchase,consumeStock};
  if(typeof module!=="undefined"&&module.exports)module.exports=root.InventoryCore;
})(typeof globalThis!=="undefined"?globalThis:this);
