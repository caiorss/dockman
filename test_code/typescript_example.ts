class MetaObject{
      constructor (public Name: string){ }
}

let obj1 = new MetaObject("Something");
let obj2 = new MetaObject("Else");

console.log(" =>> Hello world typescript ");
console.log(`\t Obj = ${obj1.Name} `);

for (let j of  [10, 9, 100, 52]){
  console.log(`j = ${j}`);
}



