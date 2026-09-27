import { createClient } from "npm:@supabase/supabase-js@2";
const supabaseUrl=Deno.env.get("SUPABASE_URL")!;
const serviceRole=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db=createClient(supabaseUrl,serviceRole,{auth:{persistSession:false}});

const cors={
  "Access-Control-Allow-Origin":"*",
  "Access-Control-Allow-Headers":"content-type,x-save-key",
  "Access-Control-Allow-Methods":"GET,POST,OPTIONS",
  "Cache-Control":"no-store"
};
const h=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:{...cors,"Content-Type":"application/json; charset=utf-8"}});
const n=(v:unknown,d:number,min=0,max=5000)=>{const value=v==null||v===""?d:Number(v);return Math.max(min,Math.min(max,Number.isFinite(value)?value:d));};
const normalizeName=(value:string)=>value.normalize("NFD").replace(/\p{Diacritic}/gu,"").toLowerCase().replace(/[^a-z0-9]+/g," ").trim();
const ageAt=(birth:string|null|undefined,at:string|null|undefined,fallback:any=null,fallbackSnapshot:string|null|undefined=null)=>{
  const target=new Date(String(at||new Date().toISOString().slice(0,10))+"T12:00:00Z");
  if(Number.isNaN(target.getTime()))return fallback;
  if(birth){
    const b=new Date(String(birth)+"T12:00:00Z");
    if(Number.isNaN(b.getTime()))return fallback;
    let a=target.getUTCFullYear()-b.getUTCFullYear();
    const md=(target.getUTCMonth()-b.getUTCMonth())*100+(target.getUTCDate()-b.getUTCDate());
    if(md<0)a--;
    return a;
  }
  if(fallback==null)return fallback;
  if(fallbackSnapshot){
    const snap=new Date(String(fallbackSnapshot)+"T12:00:00Z");
    if(!Number.isNaN(snap.getTime())){
      return Number(fallback)+(target.getUTCFullYear()-snap.getUTCFullYear());
    }
  }
  return fallback;
};
async function resolvePlayerFacts(player:any,gameDate:string){
  if(!player||!player.is_real)return player;
  if(player.birth_date){
    const exactAge=ageAt(player.birth_date,gameDate,player.age);
    const exactSource=String(player.birth_date_source||"Date de naissance enregistrée");
    if(player.age!==exactAge||/estimation/i.test(String(player.age_source||""))||!player.age_source){
      player.age=exactAge;player.age_source=exactSource;player.age_snapshot_date=gameDate;
      try{await db.from("players").update({age:exactAge,age_source:exactSource,age_snapshot_date:gameDate}).eq("id",player.id)}catch{}
    }
  }
  let qid=String(player.wikidata_id||"").trim();
  let wikiTitle="";
  if((!qid||!/^Q\d+$/.test(qid))&&player.name){
    try{
      const qs=new URLSearchParams({
        action:"query",generator:"search",gsrsearch:'"'+String(player.name)+'" tennis',
        gsrnamespace:"0",gsrlimit:"5",prop:"pageprops",format:"json",origin:"*"
      });
      const wr=await fetch("https://en.wikipedia.org/w/api.php?"+qs.toString(),{headers:{"User-Agent":"CourtBoss/1.0"}});
      if(wr.ok){
        const wj:any=await wr.json();
        const pages=(Object.values(wj?.query?.pages||{}) as any[]).sort((a:any,b:any)=>Number(a.index??999)-Number(b.index??999));
        const target=normalizeName(String(player.name)).replace(/\s+/g,"");
        const chosen=pages.find((x:any)=>{
          const title=normalizeName(String(x.title||"")).replace(/\s+/g,"");
          return x?.pageprops?.wikibase_item&&(title.includes(target)||target.includes(title));
        })??pages.find((x:any)=>x?.pageprops?.wikibase_item);
        const found=String(chosen?.pageprops?.wikibase_item||"");
        wikiTitle=String(chosen?.title||"");
        if(/^Q\d+$/.test(found)){
          qid=found;player.wikidata_id=qid;
          await db.from("players").update({wikidata_id:qid}).eq("id",player.id);
        }
      }
    }catch{}
  }
  if((!qid||!/^Q\d+$/.test(qid))&&player.name){
    for(const lang of ["en","fr"]){
      try{
        const qs=new URLSearchParams({
          action:"wbsearchentities",
          search:String(player.name)+" tennis",
          language:lang,
          uselang:lang,
          type:"item",
          limit:"8",
          format:"json",
          origin:"*"
        });
        const wr=await fetch("https://www.wikidata.org/w/api.php?"+qs.toString(),{headers:{"User-Agent":"CourtBoss/1.0"}});
        if(!wr.ok)continue;
        const wj:any=await wr.json();
        const target=normalizeName(String(player.name)).replace(/\s+/g,"");
        const choices=(wj?.search||[]).filter((x:any)=>/^Q\d+$/.test(String(x.id||"")));
        const chosen=choices.find((x:any)=>{
          const label=normalizeName(String(x.label||"")).replace(/\s+/g,"");
          return (label===target||label.includes(target)||target.includes(label))&&/tennis/i.test(String(x.description||""));
        })??choices.find((x:any)=>/tennis/i.test(String(x.description||"")));
        if(chosen?.id){
          qid=String(chosen.id);player.wikidata_id=qid;
          await db.from("players").update({wikidata_id:qid}).eq("id",player.id);
          break;
        }
      }catch{}
    }
  }

  if(!qid||!/^Q\d+$/.test(qid))return player;

  try{
    const r=await fetch("https://www.wikidata.org/wiki/Special:EntityData/"+encodeURIComponent(qid)+".json",{headers:{"User-Agent":"CourtBoss/1.0"}});
    if(!r.ok)return player;
    const j:any=await r.json(),entity=j?.entities?.[qid],claims=entity?.claims||{};
    if(!wikiTitle)wikiTitle=String(entity?.sitelinks?.enwiki?.title||"");
    const rawBirth=claims?.P569?.[0]?.mainsnak?.datavalue?.value?.time;
    const file=claims?.P18?.[0]?.mainsnak?.datavalue?.value;
    const heightClaim=claims?.P2048?.[0]?.mainsnak?.datavalue?.value;
    const update:any={};

    const atpClaim=claims?.P536?.[0]?.mainsnak?.datavalue?.value;
    const itfClaim=claims?.P8618?.[0]?.mainsnak?.datavalue?.value;
    if(typeof atpClaim==="string"&&/^[A-Za-z0-9]{4}$/.test(atpClaim)){
      const code=atpClaim.toUpperCase();
      player.atp_code=code;update.atp_code=code;
    }
    if(typeof itfClaim==="string"&&/^[a-z0-9-]+\/800\d+\/[a-z]{3}$/i.test(itfClaim)){
      const wid=itfClaim.toLowerCase();
      player.itf_player_id=wid;update.itf_player_id=wid;
    }

    if(!player.birth_date&&typeof rawBirth==="string"){
      const m=rawBirth.match(/^\+?(\d{4}-\d{2}-\d{2})T/);
      if(m){
        player.birth_date=m[1];
        player.age=ageAt(m[1],gameDate,player.age);
        player.birth_date_source="Wikidata "+qid;
        player.age_source="Wikidata "+qid;
        player.age_snapshot_date=gameDate;
        update.birth_date=m[1];update.age=player.age;update.birth_date_source=player.birth_date_source;
        update.age_source=player.age_source;update.age_snapshot_date=gameDate;
      }
    }

    if(!player.height_cm&&heightClaim?.amount){
      const amount=Math.abs(Number(heightClaim.amount));
      let cm=0;
      if(amount>1&&amount<3)cm=Math.round(amount*100);
      else if(amount>=100&&amount<230)cm=Math.round(amount);
      if(cm>=140&&cm<=230){player.height_cm=cm;update.height_cm=cm;}
    }

    if(!player.photo_url&&typeof file==="string"&&file){
      const photo="https://commons.wikimedia.org/wiki/Special:FilePath/"+encodeURIComponent(file)+"?width=640";
      player.photo_url=photo;player.photo_source="Wikimedia Commons";
      player.photo_source_url="https://www.wikidata.org/wiki/"+qid;
      update.photo_url=photo;update.photo_source=player.photo_source;update.photo_source_url=player.photo_source_url;
      update.photo_updated_at=new Date().toISOString();update.photo_checked_at=new Date().toISOString();
    }

    if((!player.backhand_verified||!player.birthplace||!player.coaches||!player.turned_pro_year||!player.weight_kg||!player.bio_verified)&&wikiTitle){
      try{
        const wq=new URLSearchParams({action:"query",prop:"revisions",rvprop:"content",rvslots:"main",titles:wikiTitle,format:"json",formatversion:"2",origin:"*"});
        const wr=await fetch("https://en.wikipedia.org/w/api.php?"+wq.toString(),{headers:{"User-Agent":"CourtBoss/1.0"}});
        if(wr.ok){
          const wj:any=await wr.json();
          const wt=String(wj?.query?.pages?.[0]?.revisions?.[0]?.slots?.main?.content||"");
          const cleanWiki=(v:any)=>String(v||"")
            .replace(/<ref[^>]*>[\s\S]*?<\/ref>/gi," ")
            .replace(/<ref[^>]*\/>/gi," ")
            .replace(/\{\{(?:convert|height|nowrap)[^}]*\}\}/gi," ")
            .replace(/\{\{[^}]+\}\}/g," ")
            .replace(/\[\[(?:[^\]|]+\|)?([^\]]+)\]\]/g,"$1")
            .replace(/<[^>]+>/g," ")
            .replace(/'{2,}/g,"")
            .replace(/&nbsp;/gi," ")
            .replace(/\s+/g," ").trim();
          const field=(...names:string[])=>{
            for(const name of names){
              const m=wt.match(new RegExp("\\\|\\\\s*"+name+"\\\\s*=\\\\s*([^\\\\n\\\\r]+)","i"));
              if(m?.[1])return cleanWiki(m[1]);
            }
            return "";
          };

          const plays=field("plays");
          let bh="";
          if(/two[- ]handed\s+backhand|double[- ]handed\s+backhand|two[- ]handed/i.test(plays))bh="2 mains";
          else if(/one[- ]handed\s+backhand|single[- ]handed\s+backhand|one[- ]handed/i.test(plays))bh="1 main";
          if(bh&&!player.backhand_verified){
            player.backhand=bh;player.backhand_verified=true;player.backhand_source="Wikipedia · "+wikiTitle;
            update.backhand=bh;update.backhand_verified=true;update.backhand_source=player.backhand_source;
          }
          if((!player.handedness||player.handedness==="Inconnue")&&plays){
            if(/left[- ]handed/i.test(plays)){player.handedness="Gaucher";update.handedness="Gaucher";}
            else if(/right[- ]handed/i.test(plays)){player.handedness="Droitier";update.handedness="Droitier";}
          }

          const birthplace=field("birth_place","birthplace");
          if(!player.birthplace&&birthplace){
            player.birthplace=birthplace.slice(0,180);update.birthplace=player.birthplace;
          }

          const coaches=field("coach","coaches");
          if(!player.coaches&&coaches){
            player.coaches=coaches.slice(0,220);update.coaches=player.coaches;
          }

          const turnedProRaw=field("turnedpro","turned_pro","turned pro");
          const proYear=Number((turnedProRaw.match(/\b(19|20)\d{2}\b/)||[])[0]||0);
          if(!player.turned_pro_year&&proYear>=1950&&proYear<=new Date().getUTCFullYear()+1){
            player.turned_pro_year=proYear;update.turned_pro_year=proYear;
          }

          const weightRaw=field("weight");
          if(!player.weight_kg&&weightRaw){
            let kg=0;
            const kgm=weightRaw.match(/(\d{2,3}(?:\.\d+)?)\s*kg/i);
            const lbm=weightRaw.match(/(\d{2,3}(?:\.\d+)?)\s*(?:lb|lbs|pounds?)/i);
            if(kgm)kg=Math.round(Number(kgm[1]));
            else if(lbm)kg=Math.round(Number(lbm[1])*.45359237);
            if(kg>=45&&kg<=150){player.weight_kg=kg;update.weight_kg=kg;}
          }

          if(birthplace||coaches||proYear||weightRaw){
            player.bio_source="Wikipedia · "+wikiTitle;
            player.bio_verified=true;
            update.bio_source=player.bio_source;update.bio_verified=true;
          }
        }
      }catch{}
    }

    if(Object.keys(update).length)await db.from("players").update(update).eq("id",player.id);
  }catch{}
  return player;
}
async function resolvePlayerPhoto(player:any){
  if(!player||!player.is_real||!player.name)return player;

  const savePhoto=async(url:string,source:string,sourceUrl:string,label:string)=>{
    player.photo_url=url;
    player.photo_source=source;
    player.photo_source_url=sourceUrl;
    player.photo_source_label=label;
    player.photo_updated_at=new Date().toISOString();
    player.photo_checked_at=new Date().toISOString();
    await db.from("players").update({
      photo_url:url,
      photo_source:source,
      photo_source_url:sourceUrl,
      photo_source_label:label,
      photo_updated_at:player.photo_updated_at,
      photo_checked_at:player.photo_checked_at
    }).eq("id",player.id);
    return player;
  };

  // 1) ATP Tour official headshot when an official ATP player code is known.
  const directCode=/^[A-Za-z0-9]{4}$/.test(String(player.source_player_id||"").trim())
    ?String(player.source_player_id).trim().toUpperCase()
    :"";
  if(!player.atp_code&&directCode){
    player.atp_code=directCode;
    try{await db.from("players").update({atp_code:directCode}).eq("id",player.id)}catch{}
  }
  const atpCode=String(player.atp_code||directCode||"").trim().toLowerCase();
  if(/^[a-z0-9]{4}$/.test(atpCode)){
    try{
      const img="https://www.atptour.com/-/media/alias/player-gladiator-headshot/"+encodeURIComponent(atpCode);
      const rr=await fetch(img,{headers:{"User-Agent":"CourtBoss/1.0","Accept":"image/avif,image/webp,image/apng,image/*,*/*;q=0.8"},redirect:"follow"});
      const ct=String(rr.headers.get("content-type")||"").toLowerCase();
      const cl=Number(rr.headers.get("content-length")||0);
      if(rr.ok&&ct.startsWith("image/")&&(cl===0||cl>1200)){
        return await savePhoto(
          img,
          "ATP Tour",
          "https://www.atptour.com/en/players/-/"+atpCode+"/overview",
          "ATP Tour · photo officielle"
        );
      }
    }catch{}
  }
  if(player.photo_url&&/^ATP Tour$/i.test(String(player.photo_source||"")))return player;

  // 2) World Tennis / ITF profile photo.
  const itfId=String(player.itf_player_id||"").trim();
  if(/^[a-z0-9-]+\/800\d+\/[a-z]{3}$/i.test(itfId)){
    const pages=[
      "https://www.itftennis.com/en/players/"+itfId+"/mt/s/overview/",
      "https://www.itftennis.com/en/players/"+itfId+"/jt/s/overview/",
      "https://www.itftennis.com/en/players/"+itfId+"/"
    ];
    for(const page of pages){
      try{
        const rr=await fetch(page,{headers:{"User-Agent":"CourtBoss/1.0 (+official player photo resolver)","Accept":"text/html"}});
        if(!rr.ok)continue;
        const html=await rr.text();
        let m=html.match(/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i)
          ||html.match(/<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i);
        let img=String(m?.[1]||"").replace(/&amp;/g,"&").trim();
        if(!/remote\.axd|assetbank-itf|media\.itftennis\.com/i.test(img)){
          const raw=html.match(/(?:https?:)?\/\/www\.itftennis\.com\/remote\.axd\/[^"'<>\s]+/i)
            ||html.match(/\/remote\.axd\/[^"'<>\s]+/i);
          img=String(raw?.[0]||"").replace(/&amp;/g,"&");
        }
        if(img.startsWith("//"))img="https:"+img;
        else if(img.startsWith("/"))img="https://www.itftennis.com"+img;
        if(img&&/^https:\/\//i.test(img)&&/remote\.axd|assetbank-itf|media\.itftennis\.com/i.test(img)){
          return await savePhoto(img,"World Tennis / ITF",page,"World Tennis / ITF · photo officielle");
        }
      }catch{}
    }
  }
  if(player.photo_url&&/World Tennis|ITF/i.test(String(player.photo_source||"")))return player;

  // Keep an existing Wikimedia photo only after both official sources have been attempted.
  if(player.photo_url)return player;

  // 3) Wikipedia / Wikimedia fallback.
  try{
    const qs=new URLSearchParams({
      action:"query",generator:"search",gsrsearch:'"'+String(player.name)+'" tennis',
      gsrnamespace:"0",gsrlimit:"5",prop:"pageimages|info",inprop:"url",piprop:"thumbnail|name",
      pithumbsize:"640",format:"json",origin:"*"
    });
    const r=await fetch("https://en.wikipedia.org/w/api.php?"+qs.toString(),{headers:{"User-Agent":"CourtBoss/1.0"}});
    if(!r.ok)return player;
    const j:any=await r.json();
    const pages=(Object.values(j?.query?.pages||{}) as any[]).sort((a:any,b:any)=>Number(a.index??999)-Number(b.index??999));
    const target=normalizeName(String(player.name)).replace(/\s+/g,"");
    const chosen=pages.find((x:any)=>x?.thumbnail?.source&&normalizeName(String(x.title||"")).replace(/\s+/g,"").includes(target))
      ??pages.find((x:any)=>x?.thumbnail?.source);
    const photo=String(chosen?.thumbnail?.source||"");
    if(photo){
      return await savePhoto(
        photo,
        "Wikipedia/Wikimedia",
        String(chosen?.fullurl||""),
        "Wikipedia / Wikimedia"
      );
    }
  }catch{}

  try{
    await db.from("players").update({
      photo_checked_at:new Date().toISOString(),
      photo_source:null,
      photo_source_label:null
    }).eq("id",player.id);
  }catch{}
  return player;
}
const CONTINENT_CODES:any={
  Europe:new Set("ALB AND AUT BEL BIH BLR BUL CRO CYP CZE DEN ESP EST FIN FRA GBR GEO GER GRE HUN IRL ISL ITA KOS LAT LTU LUX MDA MKD MLT MNE NED NOR POL POR ROU RUS SRB SLO SVK SWE SUI UKR".split(" ")),
  "North America":new Set("ANT BAH BAR BER CAN CRC CUB DOM ESA GUA HAI HON JAM MEX NCA PAN PUR TTO USA".split(" ")),
  "South America":new Set("ARG BOL BRA CHI COL ECU GUY PAR PER SUR URU VEN".split(" ")),
  Asia:new Set("AFG BAN BHU BRN CAM CHN HKG INA IND IRI IRQ ISR JPN JOR KAZ KGZ KOR KUW LAO LIB MAS MGL MYA NEP OMA PAK PLE PHI QAT KSA SIN SRI SYR TAD THA TKM TPE UAE UZB VIE".split(" ")),
  Africa:new Set("ALG ANG BEN BOT BUR BDI CMR CPV CAF CHA COM CGO COD CIV DJI EGY EQG ERI ETH GAB GAM GHA GUI GNB KEN LES LBR LBA MAD MAW MLI MRI MAR MOZ NAM NIG NGR RWA SEN SEY SLE SOM RSA SSD SUD SWZ TAN TOG TUN UGA ZAM ZIM".split(" ")),
  Oceania:new Set("AUS FIJ FSM KIR MHL NRU NZL PLW PNG SAM SOL TGA TUV VAN".split(" "))
};
const continentOf=(code:any)=>{const c=String(code||"").toUpperCase();for(const [k,set] of Object.entries(CONTINENT_CODES) as any)if(set.has(c))return k;return "Other";};

const htmlText=(v:string)=>String(v||"")
  .replace(/<script[\s\S]*?<\/script>/gi," ")
  .replace(/<style[\s\S]*?<\/style>/gi," ")
  .replace(/<[^>]+>/g," ")
  .replace(/&nbsp;|&#160;/gi," ")
  .replace(/&amp;/gi,"&").replace(/&quot;/gi,'"').replace(/&#39;|&apos;/gi,"'")
  .replace(/&#x([0-9a-f]+);/gi,(_m,h)=>String.fromCodePoint(parseInt(h,16)))
  .replace(/&#([0-9]+);/g,(_m,d)=>String.fromCodePoint(parseInt(d,10)))
  .replace(/&([a-z]+);/gi," ")
  .replace(/\s+/g," ").trim();
const rowCells=(row:string)=>{
  const cells:any[]=[];
  for(const m of row.matchAll(/<td([^>]*)>([\s\S]*?)<\/td>/gi)){
    const attrs=String(m[1]||"");
    const cm=attrs.match(/class\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))/i);
    const cls=String(cm?.[1]||cm?.[2]||cm?.[3]||"");
    cells.push({cls,text:htmlText(String(m[2]||""))});
  }
  return cells;
};
async function parseLiveTennisRanking(url:string){
  const res=await fetch(url,{headers:{"User-Agent":"CourtBoss/1.0 (+tennis-manager data refresh)","Accept":"text/html"}});
  if(!res.ok)throw new Error("live-tennis HTTP "+res.status);
  const html=await res.text();
  const tbody=(html.match(/<tbody[^>]*>([\s\S]*?)<\/tbody>/i)||[])[1]||html;
  const rows=tbody.match(/<tr\b[\s\S]*?<\/tr>/gi)||[];
  const out:any[]=[];
  for(const row of rows){
    const cells=rowCells(row);
    const rankCell=cells.find((c:any)=>(String(c.cls).split(/\s+/).includes("rk")));
    const nameCell=cells.find((c:any)=>(String(c.cls).split(/\s+/).includes("pn")));
    if(!rankCell||!nameCell)continue;
    const idx=cells.indexOf(nameCell);
    const rank=Number(String(rankCell.text||"").replace(/[^0-9]/g,""));
    const name=String(nameCell.text||"").trim();
    const age=Number(String(cells[idx+1]?.text||"").replace(/[^0-9]/g,""));
    const country=String(cells[idx+2]?.text||"").trim().toUpperCase();
    const points=Number(String(cells[idx+3]?.text||"").replace(/[^0-9]/g,""));
    if(!rank||!name||name.length<2)continue;
    out.push({
      rank,name,name_norm:normalizeName(name),
      age:Number.isFinite(age)&&age>0?age:null,
      country:/^[A-Z]{3}$/.test(country)?country:null,
      points:Number.isFinite(points)&&points>=0?points:null
    });
  }
  return out;
}

async function parseLiveTennisDoublesRace(url:string){
  const res=await fetch(url,{headers:{"User-Agent":"CourtBoss/1.0 (+tennis-manager data refresh)","Accept":"text/html"}});
  if(!res.ok)throw new Error("live-tennis race HTTP "+res.status);
  const html=await res.text();
  const tbody=(html.match(/<tbody[^>]*>([\s\S]*?)<\/tbody>/i)||[])[1]||html;
  const rows=tbody.split(/<tr\b[^>]*>/i).slice(1);
  const out:any[]=[];
  let pending:any=null;
  const isPlayer=(v:string)=>{
    const x=String(v||"").replace(/^[✓✗]\s*/,"").trim();
    return x.length>2 && /[A-Za-zÀ-ÿ]/.test(x) && !/^[A-Z]{3}$/.test(x) && !/^\d+$/.test(x) && !/qualification cut|advertisement/i.test(x);
  };
  for(const raw of rows){
    const row=raw.split(/<tr\b/i)[0];
    const cells=rowCells(row);
    const rankIdx=cells.findIndex((c:any)=>String(c.cls).split(/\s+/).includes("rk"));
    if(rankIdx>=0){
      const rank=Number(String(cells[rankIdx]?.text||"").replace(/[^0-9]/g,""));
      if(!rank){pending=null;continue}
      let pIdx=-1;
      for(let i=rankIdx+1;i<cells.length;i++){if(isPlayer(cells[i]?.text)){pIdx=i;break}}
      if(pIdx<0){pending=null;continue}
      const p1=String(cells[pIdx]?.text||"").replace(/^[✓✗]\s*/,"").trim();
      const age1=Number(String(cells[pIdx+1]?.text||"").replace(/[^0-9]/g,""));
      const country1=String(cells[pIdx+2]?.text||"").trim().toUpperCase();
      const points=Number(String(cells[pIdx+3]?.text||"").replace(/[^0-9]/g,""));
      pending={rank,player_one:p1,age_one:Number.isFinite(age1)&&age1>0?age1:null,country_one:country1,points:Number.isFinite(points)?points:0};
      continue;
    }
    if(pending){
      let pIdx=-1;
      for(let i=0;i<cells.length;i++){if(isPlayer(cells[i]?.text)){pIdx=i;break}}
      if(pIdx>=0){
        const p2=String(cells[pIdx]?.text||"").replace(/^[✓✗]\s*/,"").trim();
        const age2=Number(String(cells[pIdx+1]?.text||"").replace(/[^0-9]/g,""));
        const country2=String(cells[pIdx+2]?.text||"").trim().toUpperCase();
        out.push({...pending,player_two:p2,age_two:Number.isFinite(age2)&&age2>0?age2:null,country_two:country2});
      }
      pending=null;
    }
  }
  return out;
}


function saveId(req:Request){const k=req.headers.get("x-save-key")??"";return /^[0-9a-f-]{36}$/i.test(k)?"browser:"+k:null}
async function getManagedPlayer(select="*"){
  const c=await db.from("career_state").select("managed_player_id").eq("id","demo").maybeSingle();
  if(c.error)return {data:null,error:c.error};
  if(!c.data?.managed_player_id)return {data:null,error:{message:"Managed player missing"}};
  return await db.from("players").select(select).eq("id",c.data.managed_player_id).maybeSingle();
}

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS") return new Response(null,{status:204,headers:cors});
  const u=new URL(req.url), path=u.pathname;

  if(path.endsWith("/api/health")||path.endsWith("/court-boss")) return h({ok:true,app:"court-boss-api",version:10});

  if(path.endsWith("/api/refresh-live-rankings")&&req.method==="GET"){
    const kind=(u.searchParams.get("kind")||"both").toLowerCase();
    const snapshot=String(u.searchParams.get("date")||new Date().toISOString().slice(0,10)).slice(0,10);
    const results:any={snapshot,kind};
    const refreshOne=async(type:"singles"|"doubles")=>{
      const url=type==="singles"
        ?"https://live-tennis.eu/en/official-atp-ranking.html"
        :"https://live-tennis.eu/en/official-atp-doubles-ranking.html";
      if(type==="singles"&&snapshot!=="2025-12-01"){
        return {
          url,
          locked:true,
          snapshot:"2025-12-01",
          reason:"Le classement ATP simple de départ est figé au 1er décembre 2025; la carrière le fait ensuite évoluer."
        };
      }
      const parsed=await parseLiveTennisRanking(url);
      const applied=await db.rpc("apply_live_rankings",{p_kind:type,p_snapshot:snapshot,p_rows:parsed});
      if(applied.error)throw applied.error;
      return {url,parsed:parsed.length,applied:applied.data,top:parsed.slice(0,10),last:parsed.slice(-3)};
    };
    try{
      if(kind==="singles"||kind==="both")results.singles=await refreshOne("singles");
      if(kind==="doubles"||kind==="both")results.doubles=await refreshOne("doubles");
      return h({ok:true,...results});
    }catch(e){return h({error:String((e as any)?.message||e),...results},500)}
  }

  if(path.endsWith("/api/refresh-doubles-race")&&req.method==="GET"){
    const snapshot=String(u.searchParams.get("date")||new Date().toISOString().slice(0,10)).slice(0,10);
    try{
      const url="https://live-tennis.eu/en/atp-doubles-race.html";
      const rows=await parseLiveTennisDoublesRace(url);
      if(!rows.length)return h({error:"Doubles race parser returned 0 rows",url},500);
      const uniq=[...new Map(rows.filter((x:any)=>x.rank&&x.player_one&&x.player_two).map((x:any)=>[Number(x.rank),x])).values()]
        .sort((a:any,b:any)=>Number(a.rank)-Number(b.rank));
      const del=await db.from("doubles_race_teams").delete().eq("snapshot_date",snapshot);
      if(del.error)return h({error:del.error.message},500);
      const payload=uniq.map((x:any)=>({
        rank:x.rank,player_one:x.player_one,player_two:x.player_two,points:x.points,
        snapshot_date:snapshot,source:"Live-Tennis ATP Doubles Race · "+snapshot
      }));
      const ins=await db.from("doubles_race_teams").insert(payload);
      if(ins.error)return h({error:ins.error.message},500);
      return h({ok:true,url,snapshot,count:payload.length,rows:payload.slice(0,40)});
    }catch(e){return h({error:String((e as any)?.message||e)},500)}
  }

  if(path.endsWith("/api/refresh-races")&&req.method==="GET"){
    const snapshot=String(u.searchParams.get("date")||new Date().toISOString().slice(0,10)).slice(0,10);
    try{
      const [raceRows,nextRows]=await Promise.all([
        parseLiveTennisRanking("https://live-tennis.eu/en/atp-race.html"),
        parseLiveTennisRanking("https://live-tennis.eu/en/atp-race-next-gen.html")
      ]);
      // Apply sequentially so a player missing from the DB is created once by Race
      // and immediately reused by Next Gen, instead of creating two parallel identities.
      const raceApplied=await db.rpc("apply_secondary_live_ranking",{p_kind:"race",p_snapshot:snapshot,p_rows:raceRows});
      const nextApplied=await db.rpc("apply_secondary_live_ranking",{p_kind:"nextgen",p_snapshot:snapshot,p_rows:nextRows});
      const err=raceApplied.error||nextApplied.error;
      if(err)return h({error:err.message},500);
      return h({ok:true,snapshot,race:{parsed:raceRows.length,applied:raceApplied.data,top:raceRows.slice(0,10)},nextgen:{parsed:nextRows.length,applied:nextApplied.data,top:nextRows.slice(0,15)}});
    }catch(e){return h({error:String((e as any)?.message||e)},500)}
  }

  if(path.endsWith("/api/bootstrap")&&req.method==="GET"){
    const sid=saveId(req);
    const currentCareer=await db.from("career_state").select("*").eq("id","demo").maybeSingle();
    const [career,academy,staff,facilities,finance,board,inbox,scouting,youth,fed,news,matches,top,events,injuries,davis,training,medicalPlan,save] = await Promise.all([
      Promise.resolve(currentCareer),
      db.from("academies").select("*").eq("id","demo").maybeSingle(),
      db.from("staff").select("*").order("id"),
      db.from("facilities").select("*").order("id"),
      db.from("finances").select("*").eq("id","demo").maybeSingle(),
      db.from("board_objectives").select("*").order("priority",{ascending:true}),
      db.from("inbox_items").select("*").order("created_at",{ascending:false}).limit(20),
      db.from("scouting_assignments").select("*").order("id"),
      db.from("academy_youth").select("*").order("potential",{ascending:false}),
      db.from("federation_state").select("*").eq("nation","FRA").maybeSingle(),
      db.from("news_items").select("*").order("created_at",{ascending:false}).limit(12),
      db.from("match_history").select("*").eq("user_involved",true).order("match_date",{ascending:false}).limit(10),
      db.from("players").select("id,name,country,ranking,points,doubles_ranking,itf_ranking,age,current_ability,potential,form,fitness,morale,fatigue,style,is_real").eq("ranking_current",true).lte("ranking",30).order("ranking"),
      db.from("tournaments").select("*").eq("is_active",true).gte("start_date",currentCareer.data?.career_date||"2026-09-27").order("start_date").limit(40),
      db.from("injuries").select("*,players(id,name,country,ranking)").order("started_at",{ascending:false}).limit(30),
      db.from("davis_squad").select("id,nation,role,players(id,name,country,ranking,points,doubles_ranking,form,fitness,morale,fatigue,style)").eq("nation","FRA").order("id"),
      db.from("training_plan").select("*").order("day_index"),
      db.from("medical_plan").select("*").eq("id","demo").maybeSingle(),
      sid?db.from("game_saves").select("payload").eq("id",sid).maybeSingle():Promise.resolve({data:null,error:null})
    ]);
    const results=[career,academy,staff,facilities,finance,board,inbox,scouting,youth,fed,news,matches,top,events,injuries,davis,training,medicalPlan,save];
    const err=results.find((x:any)=>x?.error)?.error;
    if(err) return h({error:err.message},500);
    return h({
      career:career.data,academy:academy.data,staff:staff.data??[],facilities:facilities.data??[],
      finance:finance.data,board:board.data??[],inbox:inbox.data??[],scouting:scouting.data??[],
      youth:youth.data??[],federation:fed.data,news:news.data??[],matches:matches.data??[],
      topPlayers:top.data??[],
      upcoming:(events.data??[]).filter((x:any)=>String(x.start_date)>=String(career.data?.career_date||"2026-09-27")).slice(0,40),
      injuries:injuries.data??[],
      managedInjury:(injuries.data??[]).find((x:any)=>Number(x.player_id)===Number(career.data?.managed_player_id)&&x.status==="Active")??null,
      medicalPlan:medicalPlan.data??null,
      davisSquad:davis.data??[],training:training.data??[],save:save.data?.payload??null
    });
  }

  if(path.endsWith("/api/rankings")&&req.method==="GET"){
    const kind=u.searchParams.get("kind")??"singles";
    const offset=n(u.searchParams.get("offset"),0,0,50000), limit=n(u.searchParams.get("limit"),100,1,200);
    const q=(u.searchParams.get("q")??"").trim().slice(0,80);
    const country=(u.searchParams.get("country")??"").trim().toUpperCase().slice(0,3);
    const nextGenU=n(u.searchParams.get("u"),21,18,21);
    const career=await db.from("career_state").select("career_date").eq("id","demo").maybeSingle();
    const gameDate=String(career.data?.career_date||"2026-09-27");

    if(kind==="ncaa"){
      let nq=db.from("ncaa_player_registry")
        .select("id,ita_rank,school,division,season,status,snapshot_date,source_url,source_label,players!inner(id,name,country,ranking,points,doubles_ranking,age,age_source,age_snapshot_date,birth_date,current_ability,potential,form,fitness,morale,fatigue,style,data_source,photo_url,ncaa_current,ncaa_rank,ncaa_school,ncaa_division)",{count:"exact"})
        .eq("season","2026-27")
        .eq("status","Active");
      if(q)nq=nq.ilike("players.name_norm",`%${normalizeName(q)}%`);
      if(country)nq=nq.eq("players.country",country);
      nq=nq.order("ita_rank",{ascending:true,nullsFirst:false}).range(offset,offset+limit-1);
      const {data,error,count}=await nq;
      if(error)return h({error:error.message},500);
      const rows=(data??[]).map((x:any)=>{
        const p=Array.isArray(x.players)?x.players[0]:x.players;
        return {...(p||{}),ncaa_rank:x.ita_rank,ncaa_school:x.school,ncaa_division:x.division,ncaa_season:x.season,ncaa_status:x.status,ncaa_snapshot_date:x.snapshot_date,ncaa_source:x.source_label||x.source_url,age:ageAt(p?.birth_date,gameDate,p?.age,p?.age_snapshot_date)};
      });
      return h({kind,offset,limit,count:count??0,rows,eligibility:"NCAA / ITA · joueurs universitaires réels"});
    }

    let orderCol=kind==="singles"?"game_world_rank":"ranking";
    if(kind==="doubles") orderCol="doubles_ranking";
    if(kind==="race") orderCol="race_ranking";
    if(kind==="nextgen") orderCol="nextgen_ranking";
    if(kind==="itf") orderCol="itf_ranking";
    if(kind==="junior") orderCol="junior_ranking";
    let query=db.from("players")
      .select("id,name,country,is_real,game_generated,career_status,ranking,source_ranking,game_world_rank,points,ranking_snapshot_date,previous_ranking,rank_change,ranking_previous,ranking_change,best_rank_2025,doubles_ranking,doubles_points,doubles_snapshot_date,doubles_source,race_ranking,race_points,race_snapshot_date,race_source,nextgen_ranking,nextgen_points,nextgen_snapshot_date,nextgen_source,nextgen_status,itf_ranking,junior_ranking,junior_points,junior_snapshot_date,junior_source,age,age_source,age_snapshot_date,birth_date,current_ability,potential,form,fitness,morale,fatigue,style,data_source,data_snapshot,ranking_source,ranking_current,photo_url,ncaa_current,ncaa_school,ncaa_division,ncaa_rank,ncaa_status,ncaa_last_school,ncaa_verified",{count:"exact"})
      .or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*");
    if(kind==="singles"){
      query=query.not("game_world_rank","is",null).lte("game_world_rank",30000);
    } else {
      query=query.not(orderCol,"is",null).eq("is_real",true);
    }
    if(kind==="doubles") query=query.not("doubles_ranking","is",null);
    if(kind==="race") query=query.not("race_source","is",null);
    if(kind==="nextgen"){
      query=query.not("nextgen_source","is",null).not("age","is",null).lte("age",nextGenU);
    }
    if(kind==="junior"){
      query=query.not("junior_source","is",null).not("birth_date","is",null).gte("birth_date","2007-01-01");
    }
    if(q) query=query.ilike("name_norm",`%${normalizeName(q)}%`);
    if(country) query=query.eq("country",country);
    query=query.order(orderCol,{ascending:true}).range(offset,offset+limit-1);
    const {data,error,count}=await query;
    if(error) return h({error:error.message},500);
    const rows=(data??[]).map((p:any)=>({...p,age:ageAt(p.birth_date,gameDate,p.age,p.age_snapshot_date),doubles_verified:!!p.doubles_source,official_ranking:p.ranking_current?p.ranking:null,world_rank:p.game_world_rank}));
    return h({kind,offset,limit,count:count??0,rows,eligibility:kind==="nextgen"?"U"+nextGenU+" · ATP Next Gen Race 2026 · âge au snapshot/career date":kind==="junior"?"ITF Juniors · DOB vérifiée":null});
  }


  if(path.endsWith("/api/search-players")&&req.method==="GET"){
    const q=(u.searchParams.get("q")??"").trim().slice(0,80);
    const country=(u.searchParams.get("country")??"").trim().toUpperCase().slice(0,3);
    const circuit=(u.searchParams.get("circuit")??"Tous").trim();
    const ageMax=n(u.searchParams.get("age_max"),99,12,99);
    const potentialMin=n(u.searchParams.get("potential_min"),0,0,100);
    const offset=n(u.searchParams.get("offset"),0,0,50000);
    const limit=n(u.searchParams.get("limit"),60,1,120);
    const careerDateRes=await db.from("career_state").select("career_date").eq("id","demo").maybeSingle();
    const gameDate=String(careerDateRes.data?.career_date||"2026-09-27");

    let query=db.from("players")
      .select("id,name,country,is_real,ranking,game_world_rank,points,doubles_ranking,doubles_points,race_ranking,race_points,nextgen_ranking,nextgen_points,itf_ranking,junior_ranking,junior_points,age,age_source,age_snapshot_date,birth_date,birth_date_source,height_cm,handedness,backhand,backhand_source,backhand_verified,current_ability,potential,form,fitness,morale,fatigue,style,scouting_confidence,ranking_current,ranking_snapshot_date,ranking_source,data_source,circuits_2025,sackmann_id,wikidata_id,photo_url,ncaa_current,ncaa_school,ncaa_division,ncaa_rank,ncaa_status,ncaa_last_school,ncaa_verified",{count:"exact"})
      .gte("potential",potentialMin).or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*");
    if(ageMax<99) query=query.lte("age",ageMax);

    if(q) query=query.ilike("name_norm",`%${normalizeName(q)}%`);
    if(country) query=query.eq("country",country);
    if(circuit==="ATP"||circuit==="ATP classés") query=query.eq("ranking_current",true);
    if(circuit==="ATP profond") query=query.eq("is_real",true).not("ranking","is",null);
    if(circuit==="Tous réels") query=query.eq("is_real",true);
    if(circuit==="Double") query=query.not("doubles_ranking","is",null);
    if(circuit==="Race") query=query.not("race_ranking","is",null).not("race_source","is",null);
    if(circuit==="Next Gen") query=query.not("nextgen_ranking","is",null).not("nextgen_source","is",null).not("age","is",null).lte("age",21);
    if(circuit==="ITF") query=query.not("itf_ranking","is",null);
    if(circuit==="Junior") query=query.not("junior_ranking","is",null).not("junior_source","is",null).not("birth_date","is",null).gte("birth_date","2007-01-01");
    if(circuit==="NCAA") query=query.eq("ncaa_current",true);
    if(circuit==="Prospects") query=query.eq("is_real",false).gte("potential",Math.max(70,potentialMin));

    if(circuit==="ATP"||circuit==="ATP classés"||circuit==="ATP profond") query=query.order("ranking",{ascending:true,nullsFirst:false});
    else if(q&&circuit==="Tous") query=query.order("name",{ascending:true});
    else if(circuit==="Tous réels") query=query.order("name",{ascending:true});
    else if(circuit==="Double") query=query.order("doubles_ranking",{ascending:true,nullsFirst:false});
    else if(circuit==="Race") query=query.order("race_ranking",{ascending:true,nullsFirst:false});
    else if(circuit==="Next Gen") query=query.order("nextgen_ranking",{ascending:true,nullsFirst:false});
    else if(circuit==="ITF") query=query.order("itf_ranking",{ascending:true,nullsFirst:false});
    else if(circuit==="Junior") query=query.order("junior_ranking",{ascending:true,nullsFirst:false});
    else if(circuit==="NCAA") query=query.order("ncaa_rank",{ascending:true,nullsFirst:false});
    else query=query.order("potential",{ascending:false}).order("current_ability",{ascending:false});

    query=query.range(offset,offset+limit-1);
    const {data,error,count}=await query;
    if(error)return h({error:error.message},500);
    let rows=(data??[]).map((p:any)=>({...p,age:ageAt(p.birth_date,gameDate,p.age,p.age_snapshot_date)}));
    // Search/browse progressively enriches missing real-world facts without inventing DOBs.
    // ATP is already complete; NCAA/ITF pages hydrate a few missing profiles on every browse.
    if(q.length>=2||["NCAA","ITF","Junior"].includes(circuit)){
      const enrich=rows.filter((p:any)=>p.is_real&&(!p.birth_date||!p.photo_url||!p.wikidata_id||!p.backhand_verified)).slice(0,q.length>=2?4:2);
      if(enrich.length){
        const enriched=await Promise.all(enrich.map((p:any)=>resolvePlayerFacts({...p},gameDate)));
        const byId=new Map(enriched.map((p:any)=>[Number(p.id),p]));
        rows=rows.map((p:any)=>byId.get(Number(p.id))??p).map((p:any)=>({...p,age:ageAt(p.birth_date,gameDate,p.age,p.age_snapshot_date)}));
      }
    }
    return h({q,country,circuit,age_max:ageMax,potential_min:potentialMin,offset,limit,count:count??0,rows});
  }

  if(path.endsWith("/api/doubles-race")&&req.method==="GET"){
    const career=await db.from("career_state").select("career_date").eq("id","demo").maybeSingle();
    const referenceDate=String(career.data?.career_date||"2026-09-27");
    const latest=await db.from("doubles_race_teams").select("snapshot_date").lte("snapshot_date",referenceDate).order("snapshot_date",{ascending:false}).limit(1).maybeSingle();
    if(latest.error)return h({error:latest.error.message},500);
    if(!latest.data?.snapshot_date)return h({rows:[],count:0,snapshot:null,reference_date:referenceDate});
    const rows=await db.from("doubles_race_teams").select("*").eq("snapshot_date",latest.data.snapshot_date).order("rank",{ascending:true}).limit(500);
    if(rows.error)return h({error:rows.error.message},500);
    return h({rows:rows.data??[],count:(rows.data??[]).length,snapshot:latest.data.snapshot_date,reference_date:referenceDate});
  }

  if(path.endsWith("/api/player")&&req.method==="GET"){
    let id=n(u.searchParams.get("id"),0,1,99999999);
    const identity=await db.from("players").select("data_source").eq("id",id).maybeSingle();
    const canonical=identity.data?.data_source?.match(/hidden duplicate merged into (\d+)/);
    if(canonical)id=Number(canonical[1]);
    const [p,sp,titles,hist,short,matches,careerStats,finals,juniorEntries,tournamentHistory,ncaa,ncaaCareer,careerDate,legend,historicalSeasons] = await Promise.all([
      db.from("players").select("*,player_attributes(*)").eq("id",id).maybeSingle(),
      db.from("player_sponsors").select("*").eq("player_id",id).order("id"),
      db.from("player_titles").select("*").eq("player_id",id).order("title_date",{ascending:false}).limit(150),
      db.from("ranking_history").select("*").eq("player_id",id).order("snapshot_date",{ascending:false}).limit(52),
      db.from("shortlist").select("*").eq("player_id",id).maybeSingle(),
      db.from("tournament_draw_matches").select("*,tournament_runs(tournament_id,tournaments(name,start_date,surface,indoor,category,circuit))").or(`player_a_id.eq.${id},player_b_id.eq.${id}`).order("id",{ascending:false}).limit(40),
      db.from("player_career_stats").select("*").eq("player_id",id).maybeSingle(),
      db.from("player_final_results").select("*").eq("player_id",id).order("final_date",{ascending:false}).limit(200),
      db.from("junior_tournament_entries").select("id,seed,result,snapshot_date,source_url,tournaments(id,name,city,country,surface,indoor,category,start_date,end_date,is_verified,source_url)").eq("player_id",id).order("snapshot_date",{ascending:false}).limit(30),
      db.from("player_tournament_history").select("*").eq("player_id",id).order("season",{ascending:false}).order("tournament_date",{ascending:true}).limit(500),
      db.from("ncaa_player_registry").select("*").eq("player_id",id).order("snapshot_date",{ascending:false}).limit(10),
      db.from("ncaa_career").select("*").eq("player_id",id).maybeSingle(),
      db.from("career_state").select("career_date").eq("id","demo").maybeSingle(),
      db.from("historical_legend_stats").select("*").eq("player_id",id).maybeSingle(),
      db.from("historical_season_summary").select("*").eq("player_id",id).order("season",{ascending:false}).limit(80)
    ]);
    const err=p.error||sp.error||titles.error||hist.error||short.error||matches.error||careerStats.error||finals.error||juniorEntries.error||tournamentHistory.error||ncaa.error||ncaaCareer.error||careerDate.error||legend.error||historicalSeasons.error;
    if(err) return h({error:err.message},500);
    let player:any=p.data;
    if(player&&Array.isArray(player.player_attributes)) player.player_attributes=player.player_attributes[0]??null;
    let doublesTeams:any={data:[],error:null};
    if(player?.name){
      const escapedName=String(player.name).replace(/[,%()]/g," ").trim();
      doublesTeams=await db.from("doubles_race_teams").select("*").or(`player_one.ilike.%${escapedName}%,player_two.ilike.%${escapedName}%`).order("snapshot_date",{ascending:false}).order("rank",{ascending:true}).limit(20);
    }
    if(player){
      const gameDate=String(careerDate.data?.career_date||"2026-09-27");
      player.age=ageAt(player.birth_date,gameDate,player.age);
      player=await resolvePlayerFacts(player,gameDate);
      player.age=ageAt(player.birth_date,gameDate,player.age);
      player=await resolvePlayerPhoto(player);
    }
    return h({
      player,sponsors:sp.data??[],titles:titles.data??[],history:hist.data??[],shortlist:short.data??null,
      matches:matches.data??[],careerStats:careerStats.data??null,finals:finals.data??[],juniorEntries:juniorEntries.data??[],
      tournamentHistory:tournamentHistory.data??[],ncaa:ncaa.data??[],ncaaCareer:ncaaCareer.data??null,doublesTeams:doublesTeams.data??[],legend:legend.data??null,historicalSeasons:historicalSeasons.data??[]
    });
  }

  if(path.endsWith("/api/tournaments")&&req.method==="GET"){
    const offset=n(u.searchParams.get("offset"),0,0,10000), limit=n(u.searchParams.get("limit"),60,1,150);
    const circuit=(u.searchParams.get("circuit")??"").trim().slice(0,30);
    const category=(u.searchParams.get("category")??"").trim().slice(0,40);
    const q=(u.searchParams.get("q")??"").trim().slice(0,80);
    const month=(u.searchParams.get("month")??"").trim();
    const source=(u.searchParams.get("source")??"").trim();
    const surface=(u.searchParams.get("surface")??"").trim().slice(0,40);
    const from=(u.searchParams.get("from")??"").trim();
    let query=db.from("tournaments").select("*",{count:"exact"}).eq("is_active",true);
    if(circuit&&circuit!=="Tous") query=query.eq("circuit",circuit);
    if(category&&category!=="Toutes") query=query.eq("category",category);
    if(source==="Officiel") query=query.eq("is_verified",true);
    if(source==="Simulation") query=query.eq("is_verified",false);
    if(surface==="Dur intérieur") query=query.eq("surface","Dur").eq("indoor",true);
    else if(surface==="Dur extérieur"||surface==="Dur") query=query.eq("surface","Dur").eq("indoor",false);
    else if(surface&&surface!=="Toutes") query=query.eq("surface",surface);
    if(/^\d{4}-\d{2}-\d{2}$/.test(from)) query=query.gte("start_date",from);
    if(q) query=query.ilike("name",`%${q}%`);
    if(/^\d{4}-\d{2}$/.test(month)){
      const [yy,mm]=month.split("-").map(Number);
      const next=mm===12?`${yy+1}-01-01`:`${yy}-${String(mm+1).padStart(2,"0")}-01`;
      query=query.gte("start_date",month+"-01").lt("start_date",next);
    }
    query=query.order("start_date",{ascending:true}).order("is_verified",{ascending:false}).range(offset,offset+limit-1);
    const {data,error,count}=await query;
    if(error) return h({error:error.message},500);

    const year=Number((month||from||"2026").slice(0,4))||2026;
    let tbcRows:any[]=[];
    if(source!=="Simulation"){
      const tbc=await db.from("tournament_tbc_events").select("*").eq("season_year",year).order("name");
      if(!tbc.error){
        tbcRows=(tbc.data??[]).filter((x:any)=>{
          if(circuit&&circuit!=="Tous"&&x.circuit!==circuit)return false;
          if(category&&category!=="Toutes"&&x.category!==category)return false;
          if(q&&!String(x.name||"").toLowerCase().includes(q.toLowerCase()))return false;
          if(surface==="Dur intérieur"&&!(x.surface==="Dur"&&x.indoor))return false;
          if((surface==="Dur extérieur"||surface==="Dur")&&!(x.surface==="Dur"&&!x.indoor))return false;
          if(surface&&surface!=="Toutes"&&!["Dur intérieur","Dur extérieur","Dur"].includes(surface)&&x.surface!==surface)return false;
          if(month&&month!==String(year)+"-12")return false;
          return true;
        });
      }
    }
    return h({offset,limit,count:count??0,rows:data??[],tbc:tbcRows});
  }


  if(path.endsWith("/api/tournament-detail")&&req.method==="GET"){
    const id=n(u.searchParams.get("id"),0,1,99999999);
    const [t,wc,forfeits]=await Promise.all([
      db.from("tournaments").select("*").eq("id",id).eq("is_active",true).maybeSingle(),
      db.from("wildcard_requests").select("*").eq("tournament_id",id).maybeSingle(),
      db.from("tournament_forfeits").select("id,player_id,reason,players(id,name,country,ranking,junior_ranking)").eq("tournament_id",id)
    ]);
    if(t.error||wc.error||forfeits.error) return h({error:(t.error||wc.error||forfeits.error)?.message},500);
    if(!t.data) return h({error:"Tournament not found"},404);

    const drawSize=Math.max(8,Math.min(128,Number(t.data.draw_size||32)));
    const [run,doublesRun] = await Promise.all([
      db.from("tournament_runs").select("*").eq("tournament_id",id).order("played_at",{ascending:false}).limit(1).maybeSingle(),
      db.from("doubles_runs").select("*,partner:players(id,name,country,doubles_ranking)").eq("tournament_id",id).order("played_at",{ascending:false}).limit(1).maybeSingle()
    ]);
    if(run.error||doublesRun.error)return h({error:(run.error||doublesRun.error)?.message},500);
    let completedDraw:any[]=[];
    if(run.data?.id){
      const rm=await db.from("tournament_draw_matches").select("*").eq("run_id",run.data.id).order("round_no",{ascending:true}).order("id",{ascending:true});
      if(!rm.error)completedDraw=rm.data??[];
    }

    let doublesCompletedDraw:any[]=[];
    if(doublesRun.data?.id){
      const dm=await db.from("doubles_match_history").select("*").eq("run_id",doublesRun.data.id).order("id",{ascending:true});
      if(!dm.error)doublesCompletedDraw=dm.data??[];
    }

    let doublesMain:any[]=[];
    if(t.data.doubles){
      const dpool=await db.from("players")
        .select("id,name,country,doubles_ranking,doubles_points,doubles_snapshot_date,doubles_source,current_ability,potential")
        .eq("is_real",true)
        .not("doubles_ranking","is",null)
        .or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*")
        .order("doubles_ranking",{ascending:true})
        .limit(Math.min(128,Math.max(16,drawSize*2)));
      if(!dpool.error){
        const arr=dpool.data??[];
        for(let i=0;i+1<arr.length&&doublesMain.length<Math.min(32,drawSize);i+=2){
          const a:any=arr[i],b:any=arr[i+1];
          doublesMain.push({
            seed:doublesMain.length+1,
            player_a:a,player_b:b,
            team_name:String(a.name)+" / "+String(b.name),
            combined_rank:Number(a.doubles_ranking||9999)+Number(b.doubles_ranking||9999),
            source:(a.doubles_source&&b.doubles_source)?"official":"indexed"
          });
        }
      }
    }

    if(String(t.data.circuit)==="Junior"){
      const entered=await db.from("junior_tournament_entries")
        .select("id,seed,result,snapshot_date,source_url,players(id,name,country,age,junior_ranking,junior_points,current_ability,potential,form,fitness,fatigue,style)")
        .eq("tournament_id",id);
      if(entered.error)return h({error:entered.error.message},500);

      let main:any[]=[];
      if((entered.data??[]).length){
        main=(entered.data??[])
          .map((x:any)=>{
            const p=Array.isArray(x.players)?x.players[0]:x.players;
            return p?{...p,ranking:p.junior_ranking,points:p.junior_points,seed:x.seed,result:x.result,entry_source:x.source_url}:null;
          })
          .filter(Boolean)
          .sort((a:any,b:any)=>Number(a.seed||999)-Number(b.seed||999)||Number(a.ranking||9999)-Number(b.ranking||9999));
      }else{
        const pool=await db.from("players")
          .select("id,name,country,age,junior_ranking,junior_points,current_ability,potential,form,fitness,fatigue,style,junior_snapshot_date,junior_source")
          .eq("is_real",true).not("junior_source","is",null).not("junior_ranking","is",null).not("birth_date","is",null).gte("birth_date","2007-01-01")
          .order("junior_ranking",{ascending:true}).limit(drawSize);
        if(pool.error)return h({error:pool.error.message},500);
        main=(pool.data??[]).map((p:any)=>({...p,age:ageAt(p.birth_date,String(t.data.start_date||"2025-01-01"),p.age),ranking:p.junior_ranking,points:p.junior_points}));
      }
      return h({
        tournament:t.data,main,qualifying:[],junior_entries:entered.data??[],
        wildcard:wc.data??null,forfeits:forfeits.data??[],run:run.data??null,doubles_run:doublesRun.data??null,
        doubles_main:doublesMain,doubles_completed_draw:doublesCompletedDraw,completed_draw:completedDraw,
        ranking_kind:"junior"
      });
    }

    const cut=Math.max(drawSize,Number(t.data.qual_cut||t.data.direct_cut||drawSize*4));
    const pool=await db.from("players")
      .select("id,name,country,ranking,points,current_ability,potential,form,fitness,fatigue,style")
      .eq("ranking_current",true)
      .or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*")
      .lte("ranking",Math.max(cut,drawSize*5))
      .order("ranking",{ascending:true})
      .limit(Math.min(220,drawSize*3));
    if(pool.error) return h({error:pool.error.message},500);
    const blocked=new Set((forfeits.data??[]).map((x:any)=>Number(x.player_id)));
    const available=(pool.data??[]).filter((p:any)=>!blocked.has(Number(p.id)));
    const main=available.slice(0,drawSize);
    const qualifying=available.slice(drawSize,drawSize+Math.min(32,drawSize));
    return h({
      tournament:t.data,main,qualifying,wildcard:wc.data??null,forfeits:forfeits.data??[],
      run:run.data??null,doubles_run:doublesRun.data??null,doubles_main:doublesMain,doubles_completed_draw:doublesCompletedDraw,
      completed_draw:completedDraw,ranking_kind:"singles"
    });
  }

  if(path.endsWith("/api/shortlist")&&req.method==="POST"){
    let body:any; try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const playerId=n(body?.player_id,0,1,99999999);
    if(body?.active===false){
      const d=await db.from("shortlist").delete().eq("player_id",playerId);
      return d.error?h({error:d.error.message},500):h({ok:true,active:false});
    }
    const up=await db.from("shortlist").upsert({
      player_id:playerId,
      priority:String(body?.priority||"Normal").slice(0,30),
      note:String(body?.note||"").slice(0,500),
      added_at:new Date().toISOString()
    },{onConflict:"player_id"});
    return up.error?h({error:up.error.message},500):h({ok:true,active:true});
  }

  if(path.endsWith("/api/simulate")&&req.method==="POST"){
    let body:any; try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const requestedDate=String(body?.date||"").slice(0,10);
    if(requestedDate&&!/^\d{4}-\d{2}-\d{2}$/.test(requestedDate)) return h({error:"Invalid date"},400);
    const current=await db.from("career_state").select("*").eq("id","demo").maybeSingle();
    if(current.error||!current.data)return h({error:current.error?.message||"Career missing"},500);
    const previousDate=String(current.data.career_date||"2026-09-27");
    const serverNext=new Date(previousDate+"T12:00:00Z");
    serverNext.setUTCDate(serverNext.getUTCDate()+7);
    const date=serverNext.toISOString().slice(0,10);
    const week=Math.max(1,Number(current.data.week||0)+1);
    const cs=body?.career_state||{};
    const [staffRows,sponsorRows,rosterRows]=await Promise.all([
      db.from("staff").select("weekly_cost,skill"),
      db.from("sponsor_offers").select("weekly_value,status"),
      db.from("academy_roster").select("id,weekly_cost,contract_end,status,players(name)").eq("status","active")
    ]);
    const expiredRoster=(rosterRows.data??[]).filter((x:any)=>String(x.contract_end||"9999-12-31")<date);
    for(const x of expiredRoster){
      await db.from("academy_roster").update({status:"expired"}).eq("id",x.id);
      if(x.players?.name)await db.from("contracts").update({status:"expired"}).eq("subject_type","player").eq("subject_name",x.players.name);
      await db.from("inbox_items").insert({kind:"contract",title:"Contrat joueur expiré",body:(x.players?.name||"Un joueur")+" arrive en fin de contrat.",action_route:"contracts",is_read:false});
    }
    const activeRoster=(rosterRows.data??[]).filter((x:any)=>String(x.contract_end||"9999-12-31")>=date);
    const staffWeekly=(staffRows.data??[]).reduce((s:number,x:any)=>s+Number(x.weekly_cost||0),0);
    const playerWeekly=activeRoster.reduce((s:number,x:any)=>s+Number(x.weekly_cost||0),0);
    const sponsorWeekly=(sponsorRows.data??[]).filter((x:any)=>x.status==="accepted").reduce((s:number,x:any)=>s+Number(x.weekly_value||0),0);
    const weeklyNet=sponsorWeekly-staffWeekly-playerWeekly;
    const sync=await db.from("career_state").update({
      career_date:date,
      week,
      form:n(cs.form,current.data.form,0,100),
      fitness:n(cs.fitness,current.data.fitness,0,100),
      morale:n(cs.morale,current.data.morale,0,100),
      fatigue:n(cs.fatigue,current.data.fatigue,0,100),
      injury_status:String(cs.injury_status||current.data.injury_status||"Fit").slice(0,80),
      budget:Number(current.data.budget||0)+weeklyNet,
      updated_at:new Date().toISOString()
    }).eq("id","demo");
    if(sync.error)return h({error:sync.error.message},500);

    const trainingSessions=Array.isArray(body?.training)?body.training.slice(0,7):[];
    const [anthony,facilityRows,progressRows]=await Promise.all([
      getManagedPlayer("id,current_ability,potential,player_attributes(*)"),
      db.from("facilities").select("level"),
      db.from("user_training_progress").select("*")
    ]);
    let trainingResult:any={improvements:[],xp_gains:{},current_ability:Number(current.data.current_ability||56)};
    if(anthony.data){
      const attrs:any=Array.isArray(anthony.data.player_attributes)?anthony.data.player_attributes[0]:anthony.data.player_attributes||{};
      const map:any={
        "Service":["serve_power","serve_precision"],
        "Retour":["return_game","anticipation"],
        "Coup droit":["forehand"],
        "Revers":["backhand"],
        "Déplacements":["movement","speed"],
        "Endurance":["stamina","strength"],
        "Match play":["tactics","concentration","composure","fighting_spirit"],
        "Double":["volley","touch","doubles"]
      };
      const avgStaff=(staffRows.data??[]).length?(staffRows.data??[]).reduce((s:number,x:any)=>s+Number(x.skill||10),0)/(staffRows.data??[]).length:10;
      const avgFacility=(facilityRows.data??[]).length?(facilityRows.data??[]).reduce((s:number,x:any)=>s+Number(x.level||1),0)/(facilityRows.data??[]).length:1;
      const mult=.72+avgStaff/38+avgFacility/12;
      const xp:any={};
      for(const s of trainingSessions){
        for(const a of map[String(s)]||[])xp[a]=(xp[a]||0)+.52*mult;
      }
      const progressMap=new Map((progressRows.data??[]).map((x:any)=>[x.attribute,Number(x.xp||0)]));
      const attrUpdate:any={};
      let improved=0;
      for(const [a,gain] of Object.entries(xp)){
        let total=Number(progressMap.get(a)||0)+Number(gain);
        const cur=Number(attrs[a]||10);
        const threshold=3.2+cur*.22;
        if(total>=threshold&&cur<20&&Number(anthony.data.current_ability||56)<Number(anthony.data.potential||82)){
          attrUpdate[a]=cur+1;
          total-=threshold;
          trainingResult.improvements.push({attribute:a,from:cur,to:cur+1});
          improved++;
        }
        trainingResult.xp_gains[a]=Number(gain);
        await db.from("user_training_progress").upsert({attribute:a,xp:total,updated_at:new Date().toISOString()},{onConflict:"attribute"});
      }
      if(Object.keys(attrUpdate).length){
        await db.from("player_attributes").update(attrUpdate).eq("player_id",anthony.data.id);
      }
      if(improved>=2&&Number(anthony.data.current_ability||56)<Number(anthony.data.potential||82)){
        const ca=Math.min(Number(anthony.data.potential||82),Number(anthony.data.current_ability||56)+1);
        await Promise.all([
          db.from("players").update({current_ability:ca}).eq("id",anthony.data.id),
          db.from("career_state").update({current_ability:ca}).eq("id","demo")
        ]);
        trainingResult.current_ability=ca;
      }
    }

    const worldEvents=await db.rpc("simulate_world_tournaments",{p_from_date:previousDate,p_to_date:date});
    if(worldEvents.error)return h({error:worldEvents.error.message},500);
    const sim=await db.rpc("simulate_world_week",{p_week:week,p_snapshot_date:date});
    if(sim.error) return h({error:sim.error.message},500);
    const academyDev=await db.rpc("simulate_academy_roster_week",{p_week:week,p_date:date});
    if(academyDev.error)return h({error:academyDev.error.message},500);
    const [injurySim,forfeitSim]=await Promise.all([
      db.rpc("simulate_injuries_week",{p_date:date,p_week:week}),
      db.rpc("refresh_tournament_forfeits",{p_date:date})
    ]);
    if(injurySim.error||forfeitSim.error)return h({error:(injurySim.error||forfeitSim.error)?.message},500);
    const medical=await db.rpc("apply_managed_medical_week",{p_date:date});
    if(medical.error)return h({error:medical.error.message},500);
    const scouts=await db.from("scouting_assignments").select("id,progress,status");
    if(!scouts.error){
      for(const s of scouts.data??[]){
        if(s.status==="active"){
          const np=Math.min(100,Number(s.progress||0)+12);
          await db.from("scouting_assignments").update({progress:np,status:np>=100?"completed":"active"}).eq("id",s.id);
        }
      }
    }
    const [userRank,userDoubleRank]=await Promise.all([
      db.rpc("recalculate_user_ranking",{p_date:date}),
      db.rpc("recalculate_user_doubles_ranking",{p_date:date})
    ]);
    if(userRank.error||userDoubleRank.error)return h({error:(userRank.error||userDoubleRank.error)?.message},500);
    const board=await db.rpc("update_board_state");
    return h({ok:true,date,week,world:sim.data,worldTournaments:worldEvents.data,userRanking:userRank.data,userDoublesRanking:userDoubleRank.data,training:trainingResult,academyDevelopment:academyDev.data,injuries:injurySim.data,forfeits:forfeitSim.data,medical:medical.data,board:board.data,weeklyFinance:{staff:staffWeekly,players:playerWeekly,sponsors:sponsorWeekly,medical:Number(medical.data?.weekly_cost||0),net:weeklyNet-Number(medical.data?.weekly_cost||0),expired_contracts:expiredRoster.length}});
  }

  if(path.endsWith("/api/management")&&req.method==="GET"){
    const [contracts,college,shortlist,sponsors,candidates,partnerships,collegeOffers,collegeState,collegeDuals,davisTies,academyMembers,academyRoster] = await Promise.all([
      db.from("contracts").select("*").order("end_date"),
      db.from("college_teams").select("*").order("ita_rank"),
      db.from("shortlist").select("*,players(id,name,country,ranking,points,age,potential,current_ability,style)").order("added_at",{ascending:false}).limit(50),
      db.from("sponsor_offers").select("*").order("id"),
      db.from("staff_candidates").select("*").order("skill",{ascending:false}),
      db.from("doubles_partnerships").select("*,player_a:players!doubles_partnerships_player_a_id_fkey(id,name,country,ranking,doubles_ranking),player_b:players!doubles_partnerships_player_b_id_fkey(id,name,country,ranking,doubles_ranking)").order("id",{ascending:false}).limit(20),
      db.from("college_offers").select("*,team:college_teams(*)").order("scholarship_pct",{ascending:false}),
      db.from("college_career_state").select("*,team:college_teams(*)").eq("id","demo").maybeSingle(),
      db.from("college_duals").select("*,home:college_teams!college_duals_home_team_id_fkey(*),away:college_teams!college_duals_away_team_id_fkey(*)").order("match_date",{ascending:true}).limit(20),
      db.from("davis_ties").select("*,davis_rubbers(*)").order("tie_date",{ascending:true}).limit(40),
      db.from("academy_members").select("*,player:players(id,name,country,ranking,doubles_ranking,age,current_ability,potential,form,fitness,morale,fatigue,style),youth:academy_youth(id,name,country,age,current_ability,potential,style,status),progress:academy_member_progress(*)").eq("status","active").order("id"),
      db.from("academy_roster").select("*,players(id,name,country,ranking,points,doubles_ranking,age,current_ability,potential,form,fitness,morale,fatigue,style,injury_status)").eq("status","active").order("id")
    ]);
    const err=contracts.error||college.error||shortlist.error||sponsors.error||candidates.error||partnerships.error||collegeOffers.error||collegeState.error||collegeDuals.error||davisTies.error||academyMembers.error||academyRoster.error;
    if(err) return h({error:err.message},500);
    return h({contracts:contracts.data??[],college:college.data??[],shortlist:shortlist.data??[],sponsors:sponsors.data??[],candidates:candidates.data??[],partnerships:partnerships.data??[],collegeOffers:collegeOffers.data??[],collegeState:collegeState.data??null,collegeDuals:collegeDuals.data??[],davisTies:davisTies.data??[],academyMembers:academyMembers.data??[],academyRoster:academyRoster.data??[]});
  }




  if(path.endsWith("/api/ranking-ledger")&&req.method==="GET"){
    const today=(u.searchParams.get("date")??new Date().toISOString().slice(0,10)).slice(0,10);
    const rows=await db.from("user_ranking_points").select("*").eq("owner_id","demo").order("expiry_date",{ascending:true});
    if(rows.error)return h({error:rows.error.message},500);
    const active=(rows.data??[]).filter((x:any)=>x.active);
    const total=active.reduce((s:number,x:any)=>s+Number(x.points||0),0);
    return h({date:today,total,active,expired:(rows.data??[]).filter((x:any)=>!x.active)});
  }

  if(path.endsWith("/api/play-tournament")&&req.method==="POST"){
    let body:any;try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const tid=n(body?.tournament_id,0,1,99999999);
    const tactics=body?.tactics||{};
    const tacticAgg=n(tactics.aggression,58,1,100),tacticRisk=n(tactics.risk,52,1,100),tacticNet=n(tactics.net,28,1,100);
    const returnPos=String(tactics.returnPos||"Neutre");
    const [tour,career,oldRun,wc,forfeits,managedPlayer]=await Promise.all([
      db.from("tournaments").select("*").eq("id",tid).maybeSingle(),
      db.from("career_state").select("*").eq("id","demo").maybeSingle(),
      db.from("tournament_runs").select("id").eq("tournament_id",tid).maybeSingle(),
      db.from("wildcard_requests").select("*").eq("tournament_id",tid).maybeSingle(),
      db.from("tournament_forfeits").select("player_id,reason").eq("tournament_id",tid),
      getManagedPlayer("id,name,country,ranking,points,current_ability,form,fitness,fatigue,player_attributes(clay_affinity,hard_affinity,grass_affinity)")
    ]);
    if(tour.error||career.error||wc.error||forfeits.error||managedPlayer.error)return h({error:(tour.error||career.error||wc.error||forfeits.error||managedPlayer.error)?.message},500);
    if(!tour.data||!career.data||!managedPlayer.data)return h({error:"Tournament or career missing"},404);
    if(oldRun.data)return h({error:"Ce tournoi a déjà été joué dans cette sauvegarde.",run_id:oldRun.data.id},409);
    const t:any=tour.data,c:any=career.data;
    const direct=Number(t.direct_cut||0),qual=Number(t.qual_cut||0),rank=Number(c.singles_rank||9999);
    const wildcardGranted=wc.data?.status==="accepted";
    const alternateEligible=direct&&qual&&rank>qual&&rank<=qual+50;
    if(direct&&qual&&rank>qual&&!wildcardGranted&&!alternateEligible)return h({error:"Classement insuffisant. Demande une wild card."},409);
    let alternateEntered=false;
    if(alternateEligible&&!wildcardGranted){
      const gap=Math.max(1,rank-qual);
      const needed=Math.max(1,Math.ceil(gap/10));
      const availableSpots=(forfeits.data??[]).length;
      if(availableSpots<needed)return h({error:"Pas assez de forfaits pour remonter depuis la liste alternate.",alternate:true,forfeits:availableSpots},409);
      alternateEntered=true;
    }
    const drawSize=Math.max(8,Math.min(128,Number(t.draw_size||32)));
    const playersRes=await db.from("players")
      .select("id,name,country,ranking,points,current_ability,form,fitness,fatigue,player_attributes(clay_affinity,hard_affinity,grass_affinity)")
      .eq("ranking_current",true)
      .or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*")
      .order("ranking",{ascending:true}).limit(Math.min(200,Math.max(drawSize+40,80)));
    if(playersRes.error)return h({error:playersRes.error.message},500);
    const blockedIds=new Set((forfeits.data??[]).map((x:any)=>Number(x.player_id)));
    const managedId=Number(c.managed_player_id||managedPlayer.data.id);
    const pool:any[]=(playersRes.data??[])
      .filter((p:any)=>!blockedIds.has(Number(p.id))&&Number(p.id)!==managedId)
      .map((p:any)=>({...p,player_attributes:Array.isArray(p.player_attributes)?p.player_attributes[0]:p.player_attributes}));
    const surface=String(t.surface||"Dur");
    const surfKey=surface==="Terre"?"clay_affinity":surface==="Gazon"?"grass_affinity":"hard_affinity";
    const managedAttrs:any=Array.isArray(managedPlayer.data.player_attributes)?managedPlayer.data.player_attributes[0]:managedPlayer.data.player_attributes||{};
    const user:any={id:managedId,name:String(c.player_name||managedPlayer.data.name||"Joueur"),ranking:rank,current_ability:Number(c.current_ability||managedPlayer.data.current_ability||56),form:Number(c.form||managedPlayer.data.form||72),fitness:Number(c.fitness||managedPlayer.data.fitness||91),fatigue:Number(c.fatigue||managedPlayer.data.fatigue||18),player_attributes:managedAttrs,isUser:true};
    const strength=(p:any)=>{
      let base=Number(p.current_ability||50)+Number(p.form||70)*.16-Number(p.fatigue||20)*.13+Number(p.player_attributes?.[surfKey]||10)*.75+Math.max(0,18-Number(p.ranking||9999)/250);
      if(p.isUser){
        const balance=100-Math.abs(tacticAgg-62)*.22-Math.abs(tacticRisk-54)*.18;
        const surfaceNet=surface==="Gazon"?tacticNet*.035:(Boolean(t.indoor)||String(t.environment||"").toLowerCase()==="indoor")?tacticNet*.028:surface==="Dur"?tacticNet*.018:tacticNet*.006;
        const returnBonus=returnPos==="Avancée"?1.4:returnPos==="Reculée"?.8:1.1;
        base+=balance*.025+surfaceNet+returnBonus;
        if(Number(c.fatigue||18)>45&&tacticAgg>75)base-=2.8;
        if(tacticRisk>80)base-=1.8;
      }
      return base;
    };
    const play=(a:any,b:any)=>{
      const sa=strength(a),sb=strength(b),prob=1/(1+Math.exp(-(sa-sb)/7));
      const aw=Math.random()<prob,w=aw?a:b,l=aw?b:a;
      const close=Math.abs(sa-sb)<8;
      const score=close?(Math.random()<.5?"7-6 4-6 6-3":"6-4 3-6 7-5"):(Math.random()<.5?"6-3 6-4":"6-2 6-4");
      return {winner:w,loser:l,score};
    };
    const matchRows:any[]=[];
    let userAlive=true,userRound=wildcardGranted?"Wild Card":alternateEntered?"Alternate entré":"Non joué",qualifier=false,luckyLoser=false;
    if(direct&&rank>direct&&!wildcardGranted&&!alternateEntered){
      qualifier=true;
      const qOpp=pool.filter(p=>Number(p.ranking)>=Math.max(direct+1,rank-80)&&Number(p.ranking)<=Math.max(qual,rank+80)).slice(0,6);
      for(let qi=0;qi<2;qi++){
        const opp=qOpp[qi]||pool[Math.min(pool.length-1,drawSize+qi)];
        const res=play(user,opp);
        matchRows.push({round_no:-2+qi,round_name:"Q"+(qi+1),player_a_id:null,player_b_id:opp?.id??null,player_a_name:user.name,player_b_name:opp?.name||"Qualifier",winner_id:res.winner.id,winner_name:res.winner.name,score:res.score});
        if(!res.winner.isUser){
          userAlive=false;userRound="Q"+(qi+1);
          if(qi===1&&Math.random()<0.18){userAlive=true;luckyLoser=true;userRound="Lucky Loser"}
          break
        }
      }
      if(userAlive)userRound="Qualifié";
    }
    let participants=pool.slice(0,drawSize).map(x=>({...x,isUser:false}));
    if(userAlive){
      const replaceIndex=(qualifier||wildcardGranted||luckyLoser||alternateEntered)?participants.length-1:Math.min(participants.length-1,Math.max(0,Math.floor((rank-1)%participants.length)));
      participants[replaceIndex]=user;
    }
    const roundName=(n:number)=>n>=128?"R128":n>=64?"R64":n>=32?"R32":n>=16?"R16":n>=8?"QF":n>=4?"SF":"F";
    let roundNo=1;
    while(participants.length>1){
      const rn=roundName(participants.length),next:any[]=[];
      for(let i=0;i<participants.length;i+=2){
        const a=participants[i],b=participants[i+1];
        if(!b){next.push(a);continue}
        const res=play(a,b);
        matchRows.push({round_no:roundNo,round_name:rn,player_a_id:a.id,player_b_id:b.id,player_a_name:a.name,player_b_name:b.name,winner_id:res.winner.id,winner_name:res.winner.name,score:res.score});
        if((a.isUser||b.isUser)&&!res.winner.isUser){userAlive=false;userRound=rn}
        if(res.winner.isUser)userRound=rn==="F"?"Champion":rn;
        next.push(res.winner);
      }
      participants=next;roundNo++;
    }
    const champion=participants[0];
    const basePoints=(()=>{
      const cat=String(t.category||t.level||"");
      if(/Grand Chelem/i.test(cat))return 2000;if(/Masters 1000/i.test(cat))return 1000;
      if(/ATP 500/i.test(cat))return 500;if(/ATP 250/i.test(cat))return 250;
      const m=cat.match(/Challenger\s+(175|125|100|75|50)/i);if(m)return Number(m[1]);
      if(/M25/i.test(cat))return 25;if(/M15/i.test(cat))return 15;return 50;
    })();
    const mult=userRound==="Champion"?1:userRound==="F"?.65:userRound==="SF"?.4:userRound==="QF"?.2:userRound==="R16"?.1:userRound==="R32"?.05:userRound==="Qualifié"?.03:.01;
    const userPoints=Math.max(0,Math.round(basePoints*mult));
    const prizePool=Number(t.prize_money||0);
    const prizeMult=userRound==="Champion"?.18:userRound==="F"?.10:userRound==="SF"?.055:userRound==="QF"?.03:userRound==="R16"?.015:userRound==="R32"?.008:.003;
    const userPrize=Math.max(0,Math.round(prizePool*prizeMult));
    const runIns=await db.from("tournament_runs").insert({tournament_id:tid,champion_player_id:champion?.id??null,user_round:userRound,user_points:userPoints,user_prize:userPrize,status:"completed"}).select("id").single();
    if(runIns.error)return h({error:runIns.error.message},500);
    const runId=runIns.data.id;
    if(matchRows.length){
      const rows=matchRows.map(x=>({...x,run_id:runId}));
      const ins=await db.from("tournament_draw_matches").insert(rows);
      if(ins.error)return h({error:ins.error.message},500);
    }
    const userMatches=matchRows.filter(x=>x.player_a_name===user.name||x.player_b_name===user.name).map((m:any)=>{
      const won=m.winner_name===user.name;
      const risk=Math.max(0,Math.min(100,tacticRisk));
      const aggression=Math.max(0,Math.min(100,tacticAgg));
      const net=Math.max(0,Math.min(100,tacticNet));
      const stats={
        first_serve_pct:Math.max(45,Math.min(78,65-Math.round((risk-50)*.12)+Math.round(Math.random()*8-4))),
        winners:Math.max(8,Math.round(18+aggression*.17+risk*.08+Math.random()*8)),
        unforced_errors:Math.max(6,Math.round(10+risk*.16+aggression*.05+Math.random()*7)),
        net_points_won_pct:Math.max(35,Math.min(82,48+Math.round(net*.28)+Math.round(Math.random()*8-4))),
        avg_rally:Math.max(2,Math.round(7-aggression*.035+risk*.01+Math.random()*2)),
        break_points_won:Math.max(0,Math.round((won?3:2)+Math.random()*3)),
        tactical_plan:{aggression:tacticAgg,risk:tacticRisk,net:tacticNet,return_position:returnPos}
      };
      return {...m,stats};
    });
    for(const m of userMatches){
      await db.from("match_history").insert({tournament_name:t.name,match_date:t.start_date,surface:t.surface,round:m.round_name,player_a:m.player_a_name,player_b:m.player_b_name,winner:m.winner_name,score:m.score,user_involved:true,match_data:{category:t.category,circuit:t.circuit,...m.stats}});
    }
    const european=["FRA","ESP","ITA","GER","GBR","CZE","AUT","SUI","BEL","NED","POR","MON","NOR","SWE","DEN","POL","SRB","CRO","GRE"];
    const homeCountry=String(c.country||"FRA"),dest=String(t.country||"");
    const travelFatigue=dest===homeCountry?2:(european.includes(homeCountry)&&european.includes(dest)?4:8);
    const matchFatigue=userMatches.length*5;
    const totalFatigue=travelFatigue+matchFatigue;
    const newFatigue=Math.min(100,Number(c.fatigue||18)+totalFatigue);
    const newFitness=Math.max(35,Number(c.fitness||91)-Math.ceil(totalFatigue*.45));
    const newForm=Math.max(35,Math.min(100,Number(c.form||72)+(userRound==="Champion"?6:userRound==="F"?4:userRound==="SF"?2:userMatches.length?1:-1)));
    const travelCost=dest===homeCountry?120:(european.includes(dest)?380:850);
    if(userPoints>0){
      const earnedDate=String(t.end_date||t.start_date||new Date().toISOString().slice(0,10));
      const exp=new Date(earnedDate+"T12:00:00Z");exp.setUTCDate(exp.getUTCDate()+364);
      await db.from("user_ranking_points").insert({owner_id:"demo",tournament_id:tid,label:t.name,earned_date:earnedDate,expiry_date:exp.toISOString().slice(0,10),points:userPoints,active:true});
    }
    const rankCalc=await db.rpc("recalculate_user_ranking",{p_date:String(t.end_date||t.start_date||new Date().toISOString().slice(0,10))});
    if(rankCalc.error)return h({error:rankCalc.error.message},500);
    const newPoints=Number(rankCalc.data?.points??c.points??0),newRank=Number(rankCalc.data?.rank??c.singles_rank??2001);
    const newBudget=Number(c.budget||0)+userPrize-travelCost;
    if(userRound==="Champion"){
      await db.from("player_titles").insert({
        player_id:managedId,tournament_name:t.name,title_date:String(t.end_date||t.start_date),
        level:String(t.category||t.level||t.circuit||"ATP"),surface:String(t.surface||""),
        event_type:"singles",verified:false,source_label:"Court Boss · carrière simulée",origin:"game"
      });
    }
    const finState=await db.from("finances").select("prize_money,travel_cost").eq("id","demo").maybeSingle();
    await Promise.all([
      db.from("career_state").update({budget:newBudget,points:newPoints,singles_rank:newRank,fatigue:newFatigue,fitness:newFitness,form:newForm,updated_at:new Date().toISOString()}).eq("id","demo"),
      db.from("finances").update({
        prize_money:Number(finState.data?.prize_money||0)+userPrize,
        travel_cost:Number(finState.data?.travel_cost||0)+travelCost
      }).eq("id","demo"),
      db.from("news_items").insert({body:userRound==="Champion"?String(c.player_name||"Le joueur")+" remporte "+t.name+" !":String(c.player_name||"Le joueur")+" termine "+userRound+" à "+t.name+"."})
    ]);
    const board=await db.rpc("update_board_state");
    return h({ok:true,run_id:runId,tournament:t,champion:{id:champion?.id??null,name:champion?.name||user.name},user_round:userRound,user_points:userPoints,user_prize:userPrize,matches:userMatches,draw_matches:matchRows.length,travel_cost:travelCost,fatigue_added:totalFatigue,fitness:newFitness,wildcard:wildcardGranted,lucky_loser:luckyLoser,alternate:alternateEntered,new_rank:newRank,total_points:newPoints,board:board.data});
  }


  if(path.endsWith("/api/play-doubles")&&req.method==="POST"){
    let body:any;try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const tid=n(body?.tournament_id,0,1,99999999);
    const [tour,career,anth,oldRun,partnership]=await Promise.all([
      db.from("tournaments").select("*").eq("id",tid).maybeSingle(),
      db.from("career_state").select("*").eq("id","demo").maybeSingle(),
      getManagedPlayer("id,name,country,current_ability,form,fitness,fatigue,player_attributes(doubles,clay_affinity,hard_affinity,grass_affinity)"),
      db.from("doubles_runs").select("id").eq("tournament_id",tid).maybeSingle(),
      db.from("doubles_partnerships").select("*,partner:players!doubles_partnerships_player_b_id_fkey(id,name,country,doubles_ranking,current_ability,form,fitness,fatigue,player_attributes(doubles,clay_affinity,hard_affinity,grass_affinity))").order("id",{ascending:false}).limit(1).maybeSingle()
    ]);
    const err=tour.error||career.error||anth.error||oldRun.error||partnership.error;
    if(err)return h({error:err.message},500);
    if(!tour.data||!career.data||!anth.data)return h({error:"Données carrière incomplètes"},404);
    if(!tour.data.doubles)return h({error:"Ce tournoi ne propose pas le double."},409);
    if(oldRun.data)return h({error:"Le double de ce tournoi a déjà été joué.",run_id:oldRun.data.id},409);
    if(!partnership.data?.partner)return h({error:"Choisis d’abord un partenaire de double."},409);

    const t:any=tour.data,c:any=career.data;
    const partner:any={...partnership.data.partner,player_attributes:Array.isArray(partnership.data.partner.player_attributes)?partnership.data.partner.player_attributes[0]:partnership.data.partner.player_attributes};
    const anthony:any={...anth.data,player_attributes:Array.isArray(anth.data.player_attributes)?anth.data.player_attributes[0]:anth.data.player_attributes,isUser:true};
    const poolRes=await db.from("players")
      .select("id,name,country,doubles_ranking,current_ability,form,fitness,fatigue,player_attributes(doubles,clay_affinity,hard_affinity,grass_affinity)")
      .eq("is_real",true).not("doubles_ranking","is",null)
      .or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*")
      .order("doubles_ranking",{ascending:true}).limit(160);
    if(poolRes.error)return h({error:poolRes.error.message},500);
    const pool=(poolRes.data??[])
      .filter((p:any)=>p.id!==partner.id)
      .map((p:any)=>({...p,player_attributes:Array.isArray(p.player_attributes)?p.player_attributes[0]:p.player_attributes}));

    const surface=String(t.surface||"Dur");
    const key=surface==="Terre"?"clay_affinity":surface==="Gazon"?"grass_affinity":"hard_affinity";
    const playerStrength=(p:any)=>Number(p.current_ability||50)*.55+Number(p.form||70)*.12+Number(p.fitness||85)*.08-Number(p.fatigue||20)*.10+Number(p.player_attributes?.doubles||10)*1.3+Number(p.player_attributes?.[key]||10)*.55;
    const pairStrength=(a:any,b:any,chem=70)=>playerStrength(a)+playerStrength(b)+chem*.18;

    const userPair={a:anthony,b:partner,name:anthony.name+" / "+partner.name,isUser:true,strength:pairStrength(anthony,partner,Number(partnership.data.chemistry||70))};
    const pairs:any[]=[];
    for(let i=0;i+1<Math.min(pool.length,30);i+=2){
      const a=pool[i],b=pool[i+1];
      pairs.push({a,b,name:a.name+" / "+b.name,isUser:false,strength:pairStrength(a,b,68+((a.id+b.id)%20))});
    }
    const drawSize=Math.min(16,Math.max(8,2**Math.floor(Math.log2(Math.max(8,pairs.length+1)))));
    let participants=[userPair,...pairs].slice(0,drawSize);
    const matches:any[]=[];
    let userRound="R16";
    const roundName=(n:number)=>n>=16?"R16":n>=8?"QF":n>=4?"SF":"F";
    let roundNo=1;
    while(participants.length>1){
      const rn=roundName(participants.length),next:any[]=[];
      for(let i=0;i<participants.length;i+=2){
        const A=participants[i],B=participants[i+1];
        if(!B){next.push(A);continue}
        const prob=1/(1+Math.exp(-(A.strength-B.strength)/8));
        const Aw=Math.random()<prob,w=Aw?A:B;
        const close=Math.abs(A.strength-B.strength)<8;
        const score=close?(Math.random()<.5?"7-6 4-6 10-8":"6-4 3-6 10-7"):(Aw?"6-3 6-4":"4-6 3-6");
        matches.push({round_name:rn,user_pair:A.isUser?A.name:B.isUser?B.name:userPair.name,opponent_pair:A.isUser?B.name:B.isUser?A.name:A.name+" vs "+B.name,winner_pair:w.name,score});
        if((A.isUser||B.isUser)&&!w.isUser)userRound=rn;
        if(w.isUser)userRound=rn==="F"?"Champion":rn;
        next.push(w);
      }
      participants=next;roundNo++;
    }

    const cat=String(t.category||t.level||"");
    const base= /Grand Chelem/i.test(cat)?2000:/Masters 1000/i.test(cat)?1000:/ATP 500/i.test(cat)?500:/ATP 250/i.test(cat)?250:(cat.match(/Challenger\s+(175|125|100|75|50)/i)?.[1]?Number(cat.match(/Challenger\s+(175|125|100|75|50)/i)![1]):/M25/i.test(cat)?25:/M15/i.test(cat)?15:50);
    const mult=userRound==="Champion"?1:userRound==="F"?.65:userRound==="SF"?.4:userRound==="QF"?.2:.08;
    const pts=Math.max(1,Math.round(base*mult));
    const prize=Math.max(0,Math.round(Number(t.prize_money||0)*(userRound==="Champion"?.09:userRound==="F"?.055:userRound==="SF"?.032:userRound==="QF"?.018:.007)));

    const run=await db.from("doubles_runs").insert({tournament_id:tid,partnership_id:partnership.data.id,partner_id:partner.id,user_round:userRound,user_points:pts,user_prize:prize,status:"completed"}).select("id").single();
    if(run.error)return h({error:run.error.message},500);
    if(matches.length){
      const rows=matches.filter((m:any)=>m.user_pair===userPair.name).map((m:any)=>({...m,run_id:run.data.id}));
      if(rows.length){
        const ins=await db.from("doubles_match_history").insert(rows);
        if(ins.error)return h({error:ins.error.message},500);
      }
    }

    const earned=String(t.end_date||t.start_date);
    const exp=new Date(earned+"T12:00:00Z");exp.setUTCDate(exp.getUTCDate()+364);
    await db.from("user_doubles_points").insert({owner_id:"demo",tournament_id:tid,partner_id:partner.id,label:t.name,earned_date:earned,expiry_date:exp.toISOString().slice(0,10),points:pts,active:true});
    const rank=await db.rpc("recalculate_user_doubles_ranking",{p_date:earned});
    if(rank.error)return h({error:rank.error.message},500);
    if(userRound==="Champion"){
      await Promise.all([
        db.from("player_titles").insert({
          player_id:anthony.id,tournament_name:t.name,title_date:earned,
          level:String(t.category||t.level||t.circuit||"Double"),surface:String(t.surface||""),
          event_type:"doubles",partner_player_id:partner.id,partner_name:partner.name,
          verified:false,source_label:"Court Boss · carrière simulée",origin:"game"
        }),
        db.from("player_titles").insert({
          player_id:partner.id,tournament_name:t.name,title_date:earned,
          level:String(t.category||t.level||t.circuit||"Double"),surface:String(t.surface||""),
          event_type:"doubles",partner_player_id:anthony.id,partner_name:anthony.name,
          verified:false,source_label:"Court Boss · carrière simulée",origin:"game"
        })
      ]);
    }

    const finalUserMatch=matches.filter((m:any)=>m.user_pair===userPair.name).find((m:any)=>m.round_name==="F")||null;
    if(userRound==="Champion"||userRound==="F"){
      const resultLabel=userRound==="Champion"?"Champion":"Finaliste";
      await Promise.all([
        db.from("player_final_results").insert({
          player_id:anthony.id,tournament_name:t.name,final_date:earned,
          level:String(t.category||t.level||t.circuit||"Double"),surface:String(t.surface||""),
          result:resultLabel,opponent_name:finalUserMatch?.opponent_pair||null,source:"Court Boss simulation",
          event_type:"doubles",partner_player_id:partner.id,partner_name:partner.name
        }),
        db.from("player_final_results").insert({
          player_id:partner.id,tournament_name:t.name,final_date:earned,
          level:String(t.category||t.level||t.circuit||"Double"),surface:String(t.surface||""),
          result:resultLabel,opponent_name:finalUserMatch?.opponent_pair||null,source:"Court Boss simulation",
          event_type:"doubles",partner_player_id:anthony.id,partner_name:anthony.name
        })
      ]);
    }

    const singlesRun=await db.from("tournament_runs").select("id").eq("tournament_id",tid).maybeSingle();
    const travelCost=singlesRun.data?0:(String(t.country||"")===String(c.country||"FRA")?80:260);
    const fatigueAdd=matches.filter((m:any)=>m.user_pair===userPair.name).length*4+(travelCost?3:0);
    const newBudget=Number(c.budget||0)+prize-travelCost;
    const newFatigue=Math.min(100,Number(c.fatigue||18)+fatigueAdd);
    const newFitness=Math.max(35,Number(c.fitness||91)-Math.ceil(fatigueAdd*.35));
    await db.from("career_state").update({budget:newBudget,fatigue:newFatigue,fitness:newFitness,doubles_rank:Number(rank.data?.rank||c.doubles_rank),doubles_points:Number(rank.data?.points||c.doubles_points),updated_at:new Date().toISOString()}).eq("id","demo");
    await db.from("news_items").insert({body:userRound==="Champion"?String(c.player_name||anthony.name||"Le joueur")+" et "+partner.name+" remportent le double à "+t.name+" !":String(c.player_name||anthony.name||"Le joueur")+" et "+partner.name+" terminent "+userRound+" en double à "+t.name+"."});

    const board=await db.rpc("update_board_state");
    return h({ok:true,run_id:run.data.id,tournament:t,partner:{id:partner.id,name:partner.name},round:userRound,points:pts,prize,rank:rank.data?.rank,total_points:rank.data?.points,fatigue_added:fatigueAdd,travel_cost:travelCost,matches:matches.filter((m:any)=>m.user_pair===userPair.name),board:board.data});
  }

  if(path.endsWith("/api/season-summary")&&req.method==="GET"){
    const [singles,doubles,career,pts,dpts,matches]=await Promise.all([
      db.from("tournament_runs").select("*,tournaments(*)").order("played_at",{ascending:false}).limit(100),
      db.from("doubles_runs").select("*,tournaments(*),partner:players(id,name,country)").order("played_at",{ascending:false}).limit(100),
      db.from("career_state").select("*").eq("id","demo").maybeSingle(),
      db.from("user_ranking_points").select("*").eq("owner_id","demo").order("earned_date",{ascending:false}),
      db.from("user_doubles_points").select("*").eq("owner_id","demo").order("earned_date",{ascending:false}),
      db.from("match_history").select("*").eq("user_involved",true).order("match_date",{ascending:false}).limit(200)
    ]);
    const err=singles.error||doubles.error||career.error||pts.error||dpts.error||matches.error;
    if(err)return h({error:err.message},500);
    const s=singles.data??[],d=doubles.data??[],mh=matches.data??[];
    return h({
      career:career.data,
      singles:s,
      doubles:d,
      singles_points:pts.data??[],
      doubles_points:dpts.data??[],
      stats:{
        tournaments:s.length,
        singles_tournaments:s.length,
        doubles_tournaments:d.length,
        titles:s.filter((x:any)=>x.user_round==="Champion").length,
        singles_titles:s.filter((x:any)=>x.user_round==="Champion").length,
        doubles_titles:d.filter((x:any)=>x.user_round==="Champion").length,
        total_titles:s.filter((x:any)=>x.user_round==="Champion").length+d.filter((x:any)=>x.user_round==="Champion").length,
        finals:s.filter((x:any)=>x.user_round==="F").length+s.filter((x:any)=>x.user_round==="Champion").length,
        singles_finals:s.filter((x:any)=>x.user_round==="F").length+s.filter((x:any)=>x.user_round==="Champion").length,
        doubles_finals:d.filter((x:any)=>x.user_round==="F").length+d.filter((x:any)=>x.user_round==="Champion").length,
        prize:s.reduce((a:number,x:any)=>a+Number(x.user_prize||0),0)+d.reduce((a:number,x:any)=>a+Number(x.user_prize||0),0),
        matches:mh.length,
        wins:mh.filter((x:any)=>x.winner===String(career.data?.player_name||"Joueur")).length
      }
    });
  }

  if(path.endsWith("/api/schedule-advice")&&req.method==="GET"){
    const career=await db.from("career_state").select("*").eq("id","demo").maybeSingle();
    const anth=await getManagedPlayer("id,player_attributes(*)");
    if(career.error||anth.error||!career.data)return h({error:(career.error||anth.error)?.message||"Career missing"},500);
    const c:any=career.data,a:any=Array.isArray(anth.data?.player_attributes)?anth.data.player_attributes[0]:anth.data?.player_attributes||{};
    const tours=await db.from("tournaments").select("*").eq("is_active",true).in("circuit",["ATP","Challenger","ITF"]).gte("start_date",c.career_date).order("start_date",{ascending:true}).limit(180);
    if(tours.error)return h({error:tours.error.message},500);
    const european=["FRA","ESP","ITA","GER","GBR","CZE","AUT","SUI","BEL","NED","POR","MON","NOR","SWE","DEN","POL","SRB","CRO","GRE"];
    const score=(t:any)=>{
      const cut=t.direct_cut&&c.singles_rank<=t.direct_cut?30:t.qual_cut&&c.singles_rank<=t.qual_cut?18:t.qual_cut&&c.singles_rank<=t.qual_cut+50?8:-10;
      const surf=t.surface==="Terre"?Number(a.clay_affinity||10):t.surface==="Gazon"?Number(a.grass_affinity||10):Number(a.hard_affinity||10);
      const travel=t.country===c.country?10:european.includes(t.country)?5:-3;
      const fatigue=Number(c.fatigue||18)>55?-18:Number(c.fatigue||18)>35?-8:7;
      const level=/Grand Chelem|Masters 1000/i.test(String(t.category||""))?-8:/ATP 500|ATP 250/i.test(String(t.category||""))?0:/Challenger/i.test(String(t.category||""))?10:6;
      const sourceBonus=t.is_verified?8:-2;
      return Math.max(0,Math.min(100,40+cut+surf+travel+fatigue+level+sourceBonus));
    };
    const rows=(tours.data??[]).map((t:any)=>({...t,recommendation_score:score(t)})).sort((x:any,y:any)=>y.recommendation_score-x.recommendation_score);
    return h({career:{rank:c.singles_rank,fatigue:c.fatigue,fitness:c.fitness},recommended:rows.slice(0,12)});
  }


  if(path.endsWith("/api/season-history")&&req.method==="GET"){
    const {data,error}=await db.from("season_history").select("*").order("season_year",{ascending:false}).limit(20);
    return error?h({error:error.message},500):h({rows:data??[]});
  }

  if(path.endsWith("/api/rollover-season")&&req.method==="POST"){
    let body:any;try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const newYear=n(body?.new_year,new Date().getFullYear()+1,2027,2100);
    const current=await db.from("career_state").select("season_year,career_date").eq("id","demo").maybeSingle();
    if(current.error||!current.data)return h({error:current.error?.message||"Career missing"},500);
    if(newYear<=Number(current.data.season_year||2026))return h({error:"La nouvelle saison doit être supérieure à la saison actuelle."},409);
    const roll=await db.rpc("rollover_season",{p_new_year:newYear});
    if(roll.error)return h({error:roll.error.message},500);

    const existing=await db.from("tournaments").select("id",{count:"exact",head:true}).eq("is_active",true).gte("start_date",String(newYear)+"-01-01").lte("start_date",String(newYear)+"-12-31");
    if(!existing.error && Number(existing.count||0)===0){
      const prev=await db.from("tournaments").select("*").eq("is_active",true).gte("start_date",String(newYear-1)+"-01-01").lte("start_date",String(newYear-1)+"-12-31").order("start_date");
      if(!prev.error && (prev.data??[]).length){
        const shifted=(prev.data??[]).map((t:any)=>{
          const shift=(s:any)=>{
            if(!s)return null;
            const d=new Date(String(s)+"T12:00:00Z");
            d.setUTCFullYear(newYear);
            return d.toISOString().slice(0,10);
          };
          const x:any={...t};
          delete x.id;
          return {
            ...x,
            start_date:shift(t.start_date),
            end_date:shift(t.end_date),
            deadline:shift(t.deadline),
            is_verified:false,
            source_url:null,
            source_note:"Court Boss simulated calendar based on previous-season pattern",
            is_active:true
          };
        });
        for(let i=0;i<shifted.length;i+=200){
          await db.from("tournaments").insert(shifted.slice(i,i+200));
        }
      }
    }
    const [rank,doubleRank]=await Promise.all([
      db.rpc("recalculate_user_ranking",{p_date:String(newYear)+"-01-05"}),
      db.rpc("recalculate_user_doubles_ranking",{p_date:String(newYear)+"-01-05"})
    ]);
    if(rank.error||doubleRank.error)return h({error:(rank.error||doubleRank.error)?.message},500);
    return h({ok:true,rollover:roll.data,userRanking:rank.data,userDoublesRanking:doubleRank.data});
  }


  if(path.endsWith("/api/live-match/start")&&req.method==="POST"){
    let body:any;try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const surface=String(body?.surface||"Dur").slice(0,30);
    const tactics=body?.tactics||{};
    const career=await db.from("career_state").select("managed_player_id,singles_rank,player_name").eq("id","demo").maybeSingle();
    if(career.error||!career.data)return h({error:career.error?.message||"Career missing"},500);

    let opponentId=Number(body?.opponent_id||0);
    if(!opponentId){
      const rank=Math.max(1,Number(career.data.singles_rank||500));
      const lo=Math.max(1,rank-14),hi=rank+14;
      const candidates=await db.from("players")
        .select("id,name,country,ranking")
        .eq("ranking_current",true)
        .gte("ranking",lo).lte("ranking",hi)
        .order("ranking",{ascending:true}).limit(40);
      if(candidates.error)return h({error:candidates.error.message},500);
      const pool=(candidates.data??[]).filter((x:any)=>Number(x.id)!==Number(career.data.managed_player_id));
      const pick=pool.length?pool[(Number(new Date().getUTCDate())+rank)%pool.length]:null;
      opponentId=Number(pick?.id||0);
    }
    if(!opponentId)return h({error:"Aucun adversaire disponible autour de ton classement."},404);

    const opp=await db.from("players").select("id,name,country,ranking,current_ability,form,fitness,fatigue,style,player_attributes(*)").eq("id",opponentId).maybeSingle();
    if(opp.error||!opp.data)return h({error:opp.error?.message||"Adversaire introuvable"},404);
    const ins=await db.from("live_match_sessions").insert({
      opponent_id:opponentId,surface,status:"active",user_sets:0,opponent_sets:0,set_no:1,
      user_games:0,opponent_games:0,user_points:0,opponent_points:0,serving_user:true,rally_no:0,
      momentum:50,tactics,stats:{user_winners:0,user_errors:0,user_aces:0,opp_winners:0,opp_errors:0},
      score_log:[],last_point:{}
    }).select("*").single();
    if(ins.error)return h({error:ins.error.message},500);
    return h({ok:true,session:ins.data,opponent:{id:opp.data.id,name:opp.data.name,country:opp.data.country,ranking:opp.data.ranking}});
  }

  if(path.endsWith("/api/live-match/state")&&req.method==="GET"){
    const id=n(u.searchParams.get("id"),0,1,99999999);
    const session=await db.from("live_match_sessions").select("*,opponent:players(id,name,country,ranking,current_ability,form,fitness,fatigue,style)").eq("id",id).maybeSingle();
    if(session.error||!session.data)return h({error:session.error?.message||"Match introuvable"},404);
    const events=await db.from("live_match_events").select("*").eq("session_id",id).order("id",{ascending:true});
    if(events.error)return h({error:events.error.message},500);
    return h({session:session.data,events:events.data??[]});
  }

  if(path.endsWith("/api/live-match/advance")&&req.method==="POST"){
    let body:any;try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const id=n(body?.session_id,0,1,99999999);
    const session=await db.from("live_match_sessions").select("*").eq("id",id).maybeSingle();
    if(session.error||!session.data)return h({error:session.error?.message||"Match introuvable"},404);
    if(session.data.status!=="active")return h({error:"Match déjà terminé"},409);

    const [career,managed,opp]=await Promise.all([
      db.from("career_state").select("*").eq("id","demo").maybeSingle(),
      getManagedPlayer("id,current_ability,form,fitness,fatigue,player_attributes(*)"),
      db.from("players").select("id,name,country,ranking,current_ability,form,fitness,fatigue,style,player_attributes(*)").eq("id",session.data.opponent_id).maybeSingle()
    ]);
    const err=career.error||managed.error||opp.error;
    if(err||!career.data||!managed.data||!opp.data)return h({error:err?.message||"Données match incomplètes"},500);

    const tactics=body?.tactics||session.data.tactics||{};
    const ag=n(tactics.aggression,58,1,100),risk=n(tactics.risk,52,1,100),net=n(tactics.net,28,1,100);
    const ret=String(tactics.returnPos||"Neutre");
    const surface=String(session.data.surface||"Dur");
    const key=surface==="Terre"?"clay_affinity":surface==="Gazon"?"grass_affinity":"hard_affinity";
    const ua:any=Array.isArray(managed.data.player_attributes)?managed.data.player_attributes[0]:managed.data.player_attributes||{};
    const oa:any=Array.isArray(opp.data.player_attributes)?opp.data.player_attributes[0]:opp.data.player_attributes||{};

    const uBase=Number(managed.data.current_ability||56)+Number(managed.data.form||70)*.17+Number(managed.data.fitness||90)*.08-Number(managed.data.fatigue||20)*.12+Number(ua[key]||10)*.8;
    const oBase=Number(opp.data.current_ability||55)+Number(opp.data.form||70)*.17+Number(opp.data.fitness||90)*.08-Number(opp.data.fatigue||20)*.12+Number(oa[key]||10)*.8;
    const balance=2.8-Math.abs(ag-62)*.025-Math.abs(risk-55)*.02;
    const netBonus=(surface==="Gazon"?.035:surface.toLowerCase().includes("intérieur")?.028:surface.startsWith("Dur")?.018:.006)*net;
    const retBonus=ret==="Avancée"?1.4:ret==="Reculée"?.7:1.0;
    const momentum=(Number(session.data.momentum||50)-50)*.045;
    const uStrength=uBase+balance+netBonus+retBonus+momentum;
    const prob=1/(1+Math.exp(-(uStrength-oBase)/7));
    const userWon=Math.random()<prob;
    const close=Math.abs(uStrength-oBase)<7;
    const setScore=userWon?(close?(Math.random()<.5?"7-6":"7-5"):(Math.random()<.5?"6-3":"6-4")):(close?(Math.random()<.5?"6-7":"5-7"):(Math.random()<.5?"3-6":"4-6"));

    const setStats={
      first_serve_pct:Math.max(45,Math.min(78,64-Math.round((risk-50)*.12)+Math.round(Math.random()*8-4))),
      winners:Math.max(6,Math.round(8+ag*.10+risk*.05+Math.random()*6)),
      unforced_errors:Math.max(4,Math.round(5+risk*.10+ag*.03+Math.random()*5)),
      aces:Math.max(0,Math.round(Number(ua.serve_power||10)*.25+Math.random()*3)),
      net_points_won_pct:Math.max(30,Math.min(85,45+Math.round(net*.30)+Math.round(Math.random()*10-5))),
      avg_rally:Math.max(2,Math.round(7-ag*.035+risk*.008+Math.random()*2))
    };

    let us=Number(session.data.user_sets||0)+(userWon?1:0);
    let os=Number(session.data.opponent_sets||0)+(userWon?0:1);
    const complete=us>=2||os>=2;
    const momentumNew=Math.max(10,Math.min(90,Number(session.data.momentum||50)+(userWon?12:-12)));
    const prev:any=session.data.stats||{};
    const stats={
      user_winners:Number(prev.user_winners||0)+setStats.winners,
      user_errors:Number(prev.user_errors||0)+setStats.unforced_errors,
      user_aces:Number(prev.user_aces||0)+setStats.aces,
      opp_winners:Number(prev.opp_winners||0)+Math.max(5,Math.round(Number(oa.forehand||10)*.35+Math.random()*8)),
      opp_errors:Number(prev.opp_errors||0)+Math.max(4,Math.round(Math.random()*8+5))
    };

    const summary=userWon?"Tu prends le set avec un plan de jeu efficace.":"L’adversaire prend le set, ajuste ton plan avant de continuer.";
    const ev=await db.from("live_match_events").insert({
      session_id:id,set_no:Number(session.data.set_no||1),set_score:setScore,user_won:userWon,summary,stats:setStats
    }).select("*").single();
    if(ev.error)return h({error:ev.error.message},500);

    const up=await db.from("live_match_sessions").update({
      user_sets:us,opponent_sets:os,set_no:Number(session.data.set_no||1)+1,momentum:momentumNew,tactics,stats,
      status:complete?"completed":"active",completed_at:complete?new Date().toISOString():null
    }).eq("id",id).select("*").single();
    if(up.error)return h({error:up.error.message},500);

    if(complete){
      const won=us>os;
      await db.from("career_state").update({
        fatigue:Math.min(100,Number(career.data.fatigue||18)+12),
        fitness:Math.max(35,Number(career.data.fitness||91)-5),
        form:Math.max(35,Math.min(100,Number(career.data.form||72)+(won?3:-2))),
        morale:Math.max(35,Math.min(100,Number(career.data.morale||78)+(won?2:-2))),
        updated_at:new Date().toISOString()
      }).eq("id","demo");
      await db.from("match_history").insert({
        tournament_name:"Live Coaching",match_date:String(career.data.career_date),surface,
        round:"Exhibition",player_a:String(career.data.player_name||"Joueur"),player_b:String(opp.data.name),
        winner:won?String(career.data.player_name||"Joueur"):String(opp.data.name),
        score:"Sets "+us+"-"+os,user_involved:true,match_data:{live:true,stats,tactics}
      });
    }

    return h({ok:true,session:up.data,event:ev.data,opponent:opp.data,complete});
  }



  if(path.endsWith("/api/live-match/point")&&req.method==="POST"){
    let body:any;try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const id=n(body?.session_id,0,1,99999999);
    const session=await db.from("live_match_sessions").select("*,opponent:players(id,name,country,ranking,current_ability,form,fitness,fatigue,style,player_attributes(*))").eq("id",id).maybeSingle();
    if(session.error||!session.data)return h({error:session.error?.message||"Match introuvable"},404);
    if(session.data.status!=="active")return h({ok:true,session:session.data,completed:true});

    const [career,managed]=await Promise.all([
      db.from("career_state").select("*").eq("id","demo").maybeSingle(),
      getManagedPlayer("id,name,current_ability,form,fitness,fatigue,player_attributes(*)")
    ]);
    if(career.error||managed.error||!career.data||!managed.data)return h({error:(career.error||managed.error)?.message||"Données match incomplètes"},500);

    const opp:any={...session.data.opponent,player_attributes:Array.isArray(session.data.opponent?.player_attributes)?session.data.opponent.player_attributes[0]:session.data.opponent?.player_attributes||{}};
    const ua:any=Array.isArray(managed.data.player_attributes)?managed.data.player_attributes[0]:managed.data.player_attributes||{};
    const tactics=body?.tactics||session.data.tactics||{};
    const ag=n(tactics.aggression,58,1,100),risk=n(tactics.risk,52,1,100),net=n(tactics.net,28,1,100);
    const ret=String(tactics.returnPos||"Neutre");
    const surface=String(session.data.surface||"Dur");
    const key=surface==="Terre"?"clay_affinity":surface==="Gazon"?"grass_affinity":"hard_affinity";

    const uBase=Number(managed.data.current_ability||56)+Number(managed.data.form||70)*.17+Number(managed.data.fitness||90)*.08-Number(managed.data.fatigue||20)*.12+Number(ua[key]||10)*.8;
    const oBase=Number(opp.current_ability||55)+Number(opp.form||70)*.17+Number(opp.fitness||90)*.08-Number(opp.fatigue||20)*.12+Number(opp.player_attributes?.[key]||10)*.8;
    const balance=2.8-Math.abs(ag-62)*.025-Math.abs(risk-55)*.02;
    const netBonus=(surface==="Gazon"?.035:surface.toLowerCase().includes("intérieur")?.028:surface.startsWith("Dur")?.018:.006)*net;
    const retBonus=ret==="Avancée"?1.4:ret==="Reculée"?.7:1.0;
    const momentum=(Number(session.data.momentum||50)-50)*.05;
    const indoor=surface.toLowerCase().includes("intérieur");
    const serveBoost=surface==="Gazon"?3.0:indoor?2.8:surface.startsWith("Dur")?2.2:1.55;
    const pace=surface==="Terre"?-2:surface==="Gazon"?2:indoor?1.5:0;
    let uStrength=uBase+balance+netBonus+retBonus+momentum;
    let oStrength=oBase;
    if(session.data.serving_user)uStrength+=serveBoost;else oStrength+=serveBoost;

    const prob=1/(1+Math.exp(-(uStrength-oStrength)/7.5));
    const userWon=Math.random()<prob;
    let up=Number(session.data.user_points||0),op=Number(session.data.opponent_points||0);
    if(userWon)up++;else op++;

    const rallyBase=Math.max(2,Math.round(5-pace+(100-risk)/14));
    const rally=2+Math.floor(Math.random()*Math.max(3,rallyBase));
    const aceChance=Math.max(.08,Math.min(.32,.13+Number(ua.serve_power||10)*.006+(indoor?.055:surface==="Gazon"?.07:surface==="Terre"?-.035:0)));
    const shot=userWon?(Math.random()<aceChance?"ace":Math.random()<.58?"winner":"forced error"):(Math.random()<.18?"return winner":Math.random()<.58?"winner":"forced error");
    const lastPoint={
      winner:userWon?"user":"opponent",
      rally,
      shot,
      user_x:18+Math.floor(Math.random()*64),
      user_y:Math.max(56,Math.min(88,82-Math.round(net*.18)-Math.min(8,Math.floor(rally/2))+Math.floor(Math.random()*7-3))),
      opp_x:18+Math.floor(Math.random()*64),
      opp_y:Math.max(12,Math.min(44,18+Math.min(12,Math.floor(rally/2))+Math.floor(Math.random()*9-4))),
      ball_x:18+Math.floor(Math.random()*64),
      ball_y:userWon?20+Math.floor(Math.random()*28):52+Math.floor(Math.random()*28),
      zone:Math.round(net)>=70?"Pression filet":ret==="Avancée"?"Prise tôt":ret==="Reculée"?"Retour reculé":"Neutre",
      at:new Date().toISOString()
    };

    const stats:any={user_winners:0,user_errors:0,user_aces:0,opp_winners:0,opp_errors:0,double_faults:0,...(session.data.stats||{})};
    if(userWon){
      if(shot==="ace")stats.user_aces++;
      else if(shot==="winner")stats.user_winners++;
      else stats.opp_errors++;
    }else{
      if(shot==="winner"||shot==="return winner")stats.opp_winners++;
      else stats.user_errors++;
    }

    let ug=Number(session.data.user_games||0),og=Number(session.data.opponent_games||0);
    let us=Number(session.data.user_sets||0),os=Number(session.data.opponent_sets||0);
    let setNo=Number(session.data.set_no||1),gameFinished=false,setFinished=false,setWinner="";
    const userName=String(career.data.player_name||"Joueur");

    if((up>=4||op>=4)&&Math.abs(up-op)>=2){
      gameFinished=true;
      if(up>op)ug++;else og++;
      up=0;op=0;
      if(((ug>=6||og>=6)&&Math.abs(ug-og)>=2)||ug===7||og===7){
        setFinished=true;
        setWinner=ug>og?userName:String(opp.name);
        if(ug>og)us++;else os++;
      }
    }

    let status="active",completed=false;
    if(setFinished){
      if(us>=2||os>=2){status="completed";completed=true}
      else{setNo++;ug=0;og=0}
    }

    const log:any[]=Array.isArray(session.data.score_log)?session.data.score_log:[];
    if(gameFinished){
      log.push({set:Number(session.data.set_no||1),user_games:ug,opponent_games:og,winner_game:lastPoint.winner==="user"?userName:opp.name,set_finished:setFinished,set_winner:setWinner});
    }

    const momentumNew=Math.max(10,Math.min(90,
      Number(session.data.momentum||50)+(userWon?1:-1)+(gameFinished?(lastPoint.winner==="user"?3:-3):0)+(setFinished?(setWinner===userName?7:-7):0)
    ));
    const update:any={
      user_sets:us,opponent_sets:os,set_no:setNo,user_games:ug,opponent_games:og,
      user_points:up,opponent_points:op,rally_no:Number(session.data.rally_no||0)+1,last_point:lastPoint,
      serving_user:gameFinished?!session.data.serving_user:session.data.serving_user,
      momentum:momentumNew,tactics,stats,score_log:log,status,updated_at:new Date().toISOString()
    };
    if(completed)update.completed_at=new Date().toISOString();

    const saved=await db.from("live_match_sessions").update(update).eq("id",id).select("*").single();
    if(saved.error)return h({error:saved.error.message},500);

    if(completed){
      const won=us>os;
      const sets=log.filter((x:any)=>x.set_finished).map((x:any)=>String(x.user_games)+"-"+String(x.opponent_games)).join(" ");
      await db.from("match_history").insert({
        tournament_name:"Live Match Center",match_date:career.data.career_date,surface,round:"Match live",
        player_a:userName,player_b:opp.name,winner:won?userName:opp.name,score:sets,user_involved:true,
        match_data:{live:true,stats,tactics}
      });
      await db.from("career_state").update({
        fatigue:Math.min(100,Number(career.data.fatigue||18)+8),
        fitness:Math.max(35,Number(career.data.fitness||91)-3),
        form:Math.max(35,Math.min(100,Number(career.data.form||72)+(won?2:-1))),
        updated_at:new Date().toISOString()
      }).eq("id","demo");
    }

    return h({
      ok:true,session:saved.data,
      opponent:{id:opp.id,name:opp.name,country:opp.country,ranking:opp.ranking},
      point_winner:lastPoint.winner,game_finished:gameFinished,set_finished:setFinished,set_winner:setWinner,
      completed,win_probability:Math.round(prob*100),last_point:lastPoint
    });
  }


  if(path.endsWith("/api/live-match/game")&&req.method==="POST"){
    let body:any;try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const id=n(body?.session_id,0,1,99999999);
    const session=await db.from("live_match_sessions").select("*,opponent:players(id,name,country,ranking,current_ability,form,fitness,fatigue,style,player_attributes(*))").eq("id",id).maybeSingle();
    if(session.error||!session.data)return h({error:session.error?.message||"Match introuvable"},404);
    if(session.data.status!=="active")return h({ok:true,session:session.data,completed:true});

    const [career,managed]=await Promise.all([
      db.from("career_state").select("*").eq("id","demo").maybeSingle(),
      getManagedPlayer("id,name,current_ability,form,fitness,fatigue,player_attributes(*)")
    ]);
    if(career.error||managed.error||!career.data||!managed.data)return h({error:(career.error||managed.error)?.message||"Données match incomplètes"},500);

    const opp:any={...session.data.opponent,player_attributes:Array.isArray(session.data.opponent?.player_attributes)?session.data.opponent.player_attributes[0]:session.data.opponent?.player_attributes||{}};
    const ua:any=Array.isArray(managed.data.player_attributes)?managed.data.player_attributes[0]:managed.data.player_attributes||{};
    const tactics=body?.tactics||session.data.tactics||{};
    const ag=n(tactics.aggression,58,1,100),risk=n(tactics.risk,52,1,100),net=n(tactics.net,28,1,100);
    const ret=String(tactics.returnPos||"Neutre");
    const surface=String(session.data.surface||"Dur");
    const key=surface==="Terre"?"clay_affinity":surface==="Gazon"?"grass_affinity":"hard_affinity";

    const uBase=Number(managed.data.current_ability||56)+Number(managed.data.form||70)*.17+Number(managed.data.fitness||90)*.08-Number(managed.data.fatigue||20)*.12+Number(ua[key]||10)*.8;
    const oBase=Number(opp.current_ability||55)+Number(opp.form||70)*.17+Number(opp.fitness||90)*.08-Number(opp.fatigue||20)*.12+Number(opp.player_attributes?.[key]||10)*.8;
    const balance=2.8-Math.abs(ag-62)*.025-Math.abs(risk-55)*.02;
    const netBonus=(surface==="Gazon"?.035:surface.toLowerCase().includes("intérieur")?.028:surface.startsWith("Dur")?.018:.006)*net;
    const retBonus=ret==="Avancée"?1.4:ret==="Reculée"?.7:1.0;
    const momentum=(Number(session.data.momentum||50)-50)*.05;
    const indoor=surface.toLowerCase().includes("intérieur");
    const serveBoost=surface==="Gazon"?3.0:indoor?2.8:surface.startsWith("Dur")?2.1:1.55;
    let uStrength=uBase+balance+netBonus+retBonus+momentum;
    let oStrength=oBase;
    if(session.data.serving_user)uStrength+=serveBoost;else oStrength+=serveBoost;

    const prob=1/(1+Math.exp(-(uStrength-oStrength)/7.5));
    const userWon=Math.random()<prob;

    let ug=Number(session.data.user_games||0),og=Number(session.data.opponent_games||0);
    let us=Number(session.data.user_sets||0),os=Number(session.data.opponent_sets||0);
    let setNo=Number(session.data.set_no||1);
    if(userWon)ug++;else og++;

    const stats:any={user_winners:0,user_errors:0,user_aces:0,opp_winners:0,opp_errors:0,...(session.data.stats||{})};
    if(userWon){
      stats.user_winners+=1+Math.floor(Math.random()*4);
      stats.opp_errors+=Math.floor(Math.random()*3);
      if(session.data.serving_user&&Math.random()<(surface==="Gazon"?.24:indoor?.22:surface.startsWith("Dur")?.17:.11))stats.user_aces++;
    }else{
      stats.opp_winners+=1+Math.floor(Math.random()*4);
      stats.user_errors+=Math.floor(Math.random()*3);
    }

    let setFinished=false,setWinner="";
    if(((ug>=6||og>=6)&&Math.abs(ug-og)>=2)||ug===7||og===7){
      setFinished=true;
      setWinner=ug>og?String(career.data.player_name||"Joueur"):String(opp.name);
      if(ug>og)us++;else os++;
    }

    const log:any[]=Array.isArray(session.data.score_log)?session.data.score_log:[];
    log.push({set:setNo,user_games:ug,opponent_games:og,winner_game:userWon?String(career.data.player_name||"Joueur"):opp.name,set_finished:setFinished,set_winner:setWinner});

    let status="active",completed=false;
    if(setFinished){
      if(us>=2||os>=2){status="completed";completed=true}
      else{setNo++;ug=0;og=0}
    }

    const userName=String(career.data.player_name||"Joueur");
    const momentumNew=Math.max(10,Math.min(90,Number(session.data.momentum||50)+(userWon?4:-4)+(setFinished?(setWinner===userName?8:-8):0)));
    const update:any={
      user_sets:us,opponent_sets:os,set_no:setNo,user_games:ug,opponent_games:og,
      serving_user:!session.data.serving_user,momentum:momentumNew,tactics,stats,score_log:log,
      status,updated_at:new Date().toISOString()
    };
    if(completed)update.completed_at=new Date().toISOString();

    const up=await db.from("live_match_sessions").update(update).eq("id",id).select("*").single();
    if(up.error)return h({error:up.error.message},500);

    if(completed){
      const won=us>os;
      const sets=log.filter((x:any)=>x.set_finished).map((x:any)=>String(x.user_games)+"-"+String(x.opponent_games)).join(" ");
      await db.from("match_history").insert({
        tournament_name:"Live Match Center",match_date:career.data.career_date,surface,round:"Match live",
        player_a:String(career.data.player_name||"Joueur"),player_b:opp.name,winner:won?String(career.data.player_name||"Joueur"):opp.name,score:sets,user_involved:true,
        match_data:{live:true,stats,tactics}
      });
      await db.from("career_state").update({
        fatigue:Math.min(100,Number(career.data.fatigue||18)+8),
        fitness:Math.max(35,Number(career.data.fitness||91)-3),
        form:Math.max(35,Math.min(100,Number(career.data.form||72)+(won?2:-1))),
        updated_at:new Date().toISOString()
      }).eq("id","demo");
    }

    return h({
      ok:true,session:up.data,
      opponent:{id:opp.id,name:opp.name,country:opp.country,ranking:opp.ranking},
      game_winner:userWon?String(career.data.player_name||"Joueur"):opp.name,set_finished:setFinished,set_winner:setWinner,
      completed,win_probability:Math.round(prob*100)
    });
  }


  if(path.endsWith("/api/fantasy/list")&&req.method==="GET"){
    const [t,e,r]=await Promise.all([
      db.from("fantasy_tournaments").select("*").order("created_at",{ascending:false}),
      db.from("fantasy_entries").select("*,players(id,name,country,ranking,current_ability,potential,style)").order("seed",{ascending:true,nullsFirst:false}),
      db.from("fantasy_runs").select("*,champion:players(id,name,country),fantasy_matches(*)").order("created_at",{ascending:false})
    ]);
    const err=t.error||e.error||r.error;if(err)return h({error:err.message},500);
    return h({tournaments:t.data??[],entries:e.data??[],runs:r.data??[]});
  }

  if(path.endsWith("/api/fantasy/create")&&req.method==="POST"){
    let body:any;try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const name=String(body?.name||"Court Boss Invitational").trim().slice(0,80);
    const surface=["Dur","Terre","Gazon"].includes(String(body?.surface))?String(body.surface):"Dur";
    const draw=[8,16,32,64].includes(Number(body?.draw_size))?Number(body.draw_size):16;
    const best=[3,5].includes(Number(body?.best_of))?Number(body.best_of):3;
    const ins=await db.from("fantasy_tournaments").insert({name,surface,draw_size:draw,best_of:best,status:"draft"}).select("*").single();
    return ins.error?h({error:ins.error.message},500):h({ok:true,tournament:ins.data});
  }

  if(path.endsWith("/api/fantasy/entry")&&req.method==="POST"){
    let body:any;try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const fantasyId=n(body?.fantasy_id,0,1,99999999),playerId=n(body?.player_id,0,1,99999999);
    const mode=String(body?.mode||"add");
    if(mode==="remove"){
      const d=await db.from("fantasy_entries").delete().eq("fantasy_id",fantasyId).eq("player_id",playerId);
      return d.error?h({error:d.error.message},500):h({ok:true,removed:true});
    }
    const tour=await db.from("fantasy_tournaments").select("draw_size").eq("id",fantasyId).maybeSingle();
    if(tour.error||!tour.data)return h({error:"Tournoi fantasy introuvable"},404);
    const cnt=await db.from("fantasy_entries").select("id",{count:"exact",head:true}).eq("fantasy_id",fantasyId);
    if(cnt.error)return h({error:cnt.error.message},500);
    if(Number(cnt.count||0)>=Number(tour.data.draw_size))return h({error:"Tableau déjà complet"},409);
    const up=await db.from("fantasy_entries").upsert({fantasy_id:fantasyId,player_id:playerId,seed:Number(cnt.count||0)+1},{onConflict:"fantasy_id,player_id"});
    return up.error?h({error:up.error.message},500):h({ok:true});
  }

  if(path.endsWith("/api/fantasy/run")&&req.method==="POST"){
    let body:any;try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const fantasyId=n(body?.fantasy_id,0,1,99999999);
    const [tour,entries]=await Promise.all([
      db.from("fantasy_tournaments").select("*").eq("id",fantasyId).maybeSingle(),
      db.from("fantasy_entries").select("*,players(id,name,country,ranking,current_ability,form,fitness,fatigue,player_attributes(*))").eq("fantasy_id",fantasyId).order("seed",{ascending:true})
    ]);
    const err=tour.error||entries.error;if(err)return h({error:err.message},500);
    if(!tour.data)return h({error:"Tournoi fantasy introuvable"},404);
    const t:any=tour.data;
    const flat=(p:any)=>({...p,player_attributes:Array.isArray(p.player_attributes)?p.player_attributes[0]:p.player_attributes});
    let participants=(entries.data??[]).map((x:any)=>flat(x.players)).filter(Boolean);
    if(participants.length<2)return h({error:"Ajoute au moins 2 joueurs"},409);
    const desired=Math.min(Number(t.draw_size||16),participants.length);
    const pow=2**Math.floor(Math.log2(desired));
    participants=participants.slice(0,pow);
    const key=t.surface==="Terre"?"clay_affinity":t.surface==="Gazon"?"grass_affinity":"hard_affinity";
    const strength=(p:any)=>Number(p.current_ability||50)+Number(p.form||70)*.14+Number(p.fitness||85)*.07-Number(p.fatigue||20)*.08+Number(p.player_attributes?.[key]||10)*.75;
    const matches:any[]=[];
    const rn=(n:number)=>n>=64?"R64":n>=32?"R32":n>=16?"R16":n>=8?"QF":n>=4?"SF":"F";
    while(participants.length>1){
      const round=rn(participants.length),next:any[]=[];
      for(let i=0;i<participants.length;i+=2){
        const a=participants[i],b=participants[i+1];
        const prob=1/(1+Math.exp(-(strength(a)-strength(b))/7));
        const aw=Math.random()<prob,w=aw?a:b;
        const close=Math.abs(strength(a)-strength(b))<7;
        const score=close?(Math.random()<.5?"7-6 4-6 6-3":"6-4 3-6 7-5"):(aw?"6-3 6-4":"4-6 3-6");
        matches.push({round_name:round,player_a_id:a.id,player_b_id:b.id,player_a_name:a.name,player_b_name:b.name,winner_id:w.id,winner_name:w.name,score});
        next.push(w);
      }
      participants=next;
    }
    const champ=participants[0];
    const run=await db.from("fantasy_runs").insert({fantasy_id:fantasyId,champion_player_id:champ.id}).select("*").single();
    if(run.error)return h({error:run.error.message},500);
    const ins=await db.from("fantasy_matches").insert(matches.map(m=>({...m,run_id:run.data.id})));
    if(ins.error)return h({error:ins.error.message},500);
    await db.from("fantasy_tournaments").update({status:"completed"}).eq("id",fantasyId);
    return h({ok:true,run:{...run.data,champion:champ,matches}});
  }

  if(path.endsWith("/api/manager-action")&&req.method==="POST"){
    let body:any; try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const action=String(body?.action||"");
    const id=n(body?.id,0,1,99999999);
    const career=await db.from("career_state").select("*").eq("id","demo").maybeSingle();
    if(career.error||!career.data) return h({error:career.error?.message||"Career not found"},500);
    let budget=Number(career.data.budget||0);

    if(action==="sign_youth"){
      const y=await db.from("academy_youth").select("*").eq("id",id).maybeSingle();
      if(y.error||!y.data)return h({error:y.error?.message||"Prospect not found"},404);

      const existingRoster=await db.from("academy_roster").select("*,players(*)").eq("source_youth_id",id).maybeSingle();
      if(existingRoster.error)return h({error:existingRoster.error.message},500);
      if(existingRoster.data)return h({ok:true,already:true,budget,roster:existingRoster.data});

      const cost=Number(y.data.scholarship_cost||0);
      if(budget<cost)return h({error:"Budget insuffisant"},409);
      budget-=cost;

      let playerId:number|null=null;
      const existingPlayer=await db.from("players").select("id").eq("slug","academy-youth-"+id).maybeSingle();
      if(existingPlayer.error)return h({error:existingPlayer.error.message},500);

      if(existingPlayer.data?.id){
        playerId=Number(existingPlayer.data.id);
      }else{
        const ca=Number(y.data.current_ability||45),pa=Number(y.data.potential||70);
        const ins=await db.from("players").insert({
          slug:"academy-youth-"+id,
          name:y.data.name,
          country:y.data.country||"FRA",
          is_real:false,
          ranking:2001+Number(id),
          source_ranking:null,
          points:0,
          doubles_ranking:2500+Number(id),
          itf_ranking:Number(y.data.age||18)>=18?900+Number(id):null,
          junior_ranking:Number(y.data.age||18)<=18?300+Number(id):null,
          age:Number(y.data.age||18),
          height_cm:174+(Number(id)%18),
          weight_kg:66+(Number(id)%16),
          handedness:(Number(id)%5===0?"Gaucher":"Droitier"),
          backhand:(Number(id)%7===0?"1 main":"2 mains"),
          style:y.data.style||"À définir",
          current_ability:ca,
          potential:pa,
          form:68,
          fitness:91,
          morale:82,
          fatigue:10,
          scouting_confidence:100,
          injury_status:"Fit",
          data_source:"Court Boss academy generated player",
          data_snapshot:new Date().toISOString().slice(0,10),
          ranking_current:false
        }).select("id").single();
        if(ins.error)return h({error:ins.error.message},500);
        playerId=Number(ins.data.id);

        const base=Math.max(5,Math.min(17,Math.round(ca/6)));
        const attr=(salt:number)=>Math.max(4,Math.min(20,base+((Number(id)*salt)%5)-2));
        const attrs=await db.from("player_attributes").insert({
          player_id:playerId,
          serve_power:attr(3),serve_precision:attr(5),forehand:attr(7),backhand:attr(11),return_game:attr(13),
          volley:attr(17),touch:attr(19),movement:attr(23),speed:attr(29),stamina:attr(31),strength:attr(37),
          anticipation:attr(41),concentration:attr(43),composure:attr(47),fighting_spirit:attr(53),tactics:attr(59),
          doubles:attr(61),clay_affinity:attr(67),hard_affinity:attr(71),grass_affinity:attr(73)
        });
        if(attrs.error)return h({error:attrs.error.message},500);
      }

      const weeklyCost=Math.max(80,Math.round(Number(y.data.current_ability||45)*4.5));
      const start=String(career.data.career_date||new Date().toISOString().slice(0,10));
      const endDate=new Date(start+"T12:00:00Z");endDate.setUTCFullYear(endDate.getUTCFullYear()+2);

      const roster=await db.from("academy_roster").insert({
        player_id:playerId,
        source_youth_id:id,
        contract_start:start,
        contract_end:endDate.toISOString().slice(0,10),
        weekly_cost:weeklyCost,
        squad_role:"Développement",
        development_focus:"Équilibré",
        status:"active"
      }).select("*,players(*)").single();
      if(roster.error)return h({error:roster.error.message},500);

      const [u1,u2]=await Promise.all([
        db.from("academy_youth").update({status:"signed"}).eq("id",id),
        db.from("career_state").update({budget,updated_at:new Date().toISOString()}).eq("id","demo")
      ]);
      if(u1.error||u2.error)return h({error:(u1.error||u2.error)?.message},500);

      await db.from("contracts").insert({
        subject_type:"player",
        subject_name:y.data.name,
        role:"Prospect académie",
        weekly_salary:weeklyCost,
        start_date:start,
        end_date:endDate.toISOString().slice(0,10),
        bonuses:{progression_bonus:250,top1000_bonus:500},
        status:"active"
      });

      await db.from("inbox_items").insert({kind:"academy",title:"Prospect signé",body:y.data.name+" rejoint officiellement l’académie avec un contrat de 2 ans.",action_route:"academy",is_read:false});
      return h({ok:true,budget,status:"signed",player_id:playerId,roster:roster.data});
    }

    if(action==="hire_staff"){
      const cand=await db.from("staff_candidates").select("*").eq("id",id).maybeSingle();
      if(cand.error||!cand.data)return h({error:cand.error?.message||"Candidate not found"},404);
      if(cand.data.status==="hired")return h({ok:true,already:true,budget});
      const cost=Number(cand.data.signing_cost||0);
      if(budget<cost)return h({error:"Budget insuffisant"},409);
      budget-=cost;
      const [ins,up,car]=await Promise.all([
        db.from("staff").insert({role:cand.data.role+" · "+cand.data.name,skill:cand.data.skill,weekly_cost:cand.data.weekly_cost}),
        db.from("staff_candidates").update({status:"hired"}).eq("id",id),
        db.from("career_state").update({budget,updated_at:new Date().toISOString()}).eq("id","demo")
      ]);
      const err=ins.error||up.error||car.error;if(err)return h({error:err.message},500);
      await db.from("inbox_items").insert({kind:"staff",title:"Recrutement staff",body:cand.data.name+" rejoint ton équipe comme "+cand.data.role+".",action_route:"staff",is_read:false});
      return h({ok:true,budget,status:"hired"});
    }

    if(action==="accept_sponsor"){
      const offer=await db.from("sponsor_offers").select("*").eq("id",id).maybeSingle();
      if(offer.error||!offer.data)return h({error:offer.error?.message||"Offer not found"},404);
      if(offer.data.status!=="available")return h({error:"Offre indisponible"},409);
      budget+=Number(offer.data.signing_bonus||0);
      const [up,car]=await Promise.all([
        db.from("sponsor_offers").update({status:"accepted"}).eq("id",id),
        db.from("career_state").update({budget,updated_at:new Date().toISOString()}).eq("id","demo")
      ]);
      if(up.error||car.error)return h({error:(up.error||car.error)?.message},500);
      await db.from("inbox_items").insert({kind:"commercial",title:"Sponsor signé",body:"Accord signé avec "+offer.data.brand+". Bonus : "+offer.data.signing_bonus+" €.",action_route:"finance",is_read:false});
      return h({ok:true,budget,status:"accepted"});
    }

    if(action==="renew_contract"){
      const con=await db.from("contracts").select("*").eq("id",id).maybeSingle();
      if(con.error||!con.data)return h({error:con.error?.message||"Contract not found"},404);
      const d=new Date((con.data.end_date||"2026-12-31")+"T12:00:00Z");d.setUTCFullYear(d.getUTCFullYear()+1);
      const salary=Math.round(Number(con.data.weekly_salary||0)*1.08);
      const up=await db.from("contracts").update({end_date:d.toISOString().slice(0,10),weekly_salary:salary,status:"active"}).eq("id",id);
      if(up.error)return h({error:up.error.message},500);
      return h({ok:true,end_date:d.toISOString().slice(0,10),weekly_salary:salary});
    }

    if(action==="choose_partner"){
      const anth=await getManagedPlayer("id");
      const partner=await db.from("players").select("id,name,current_ability,doubles_ranking").eq("id",id).maybeSingle();
      if(anth.error||partner.error||!anth.data||!partner.data)return h({error:"Joueur introuvable"},404);
      await db.from("doubles_partnerships").delete().eq("player_a_id",anth.data.id);
      const chemistry=65+((id*7)%29),compatibility=68+((id*11)%27),pair_strength=Math.min(96,Math.round((Number(partner.data.current_ability||50)+56)/2));
      const ins=await db.from("doubles_partnerships").insert({player_a_id:anth.data.id,player_b_id:id,chemistry,compatibility,pair_strength});
      if(ins.error)return h({error:ins.error.message},500);
      return h({ok:true,chemistry,compatibility,pair_strength});
    }

    if(action==="davis_role"){
      const role=String(body?.role||"Réserve").slice(0,40);
      const up=await db.from("davis_squad").update({role}).eq("player_id",id).eq("nation","FRA");
      if(up.error)return h({error:up.error.message},500);
      return h({ok:true,role});
    }


    if(action==="commit_college"){
      const offer=await db.from("college_offers").select("*,team:college_teams(*)").eq("id",id).maybeSingle();
      if(offer.error||!offer.data)return h({error:offer.error?.message||"Offer not found"},404);
      const managedId=Number(career.data.managed_player_id||0);
      if(!managedId)return h({error:"Joueur géré introuvable"},409);
      await db.from("college_offers").update({status:"declined"}).neq("id",id).eq("status","available");
      const today=String(career.data.career_date||new Date().toISOString().slice(0,10));
      const season=String(new Date(today+"T12:00:00Z").getUTCFullYear());
      const [o,stateUp,playerUp,ncaaUp]=await Promise.all([
        db.from("college_offers").update({status:"accepted"}).eq("id",id),
        db.from("college_career_state").update({chosen_team_id:offer.data.team_id,scholarship_pct:offer.data.scholarship_pct,status:"committed",lineup_position:6,coach_trust:62}).eq("id","demo"),
        db.from("players").update({
          ncaa_current:true,ncaa_status:"Active",ncaa_last_school:String(offer.data.team.name||"Université"),
          ncaa_verified:true,ncaa_school:String(offer.data.team.name||"Université"),ncaa_division:"NCAA Division I"
        }).eq("id",managedId),
        db.from("ncaa_career").upsert({
          player_id:managedId,school:String(offer.data.team.name||"Université"),division:"NCAA Division I",
          start_season:season,status:"Active",verified:true,source_label:"Court Boss save · engagement NCAA enregistré",
          last_verified_at:new Date().toISOString()
        },{onConflict:"player_id"})
      ]);
      const err=o.error||stateUp.error||playerUp.error||ncaaUp.error;if(err)return h({error:err.message},500);
      await db.from("inbox_items").insert({kind:"college",title:"Engagement NCAA",body:String(career.data.player_name||"Le joueur")+" s’engage avec "+offer.data.team.name+" ("+offer.data.scholarship_pct+"% de bourse).",action_route:"university",is_read:false});
      return h({ok:true,team:offer.data.team,status:"committed",ncaa_status:"Active"});
    }

    if(action==="turn_pro_college"){
      const managedId=Number(career.data.managed_player_id||0);
      if(!managedId)return h({error:"Joueur géré introuvable"},409);
      const cs=await db.from("college_career_state").select("*,team:college_teams(*)").eq("id","demo").maybeSingle();
      if(cs.error||!cs.data)return h({error:cs.error?.message||"Carrière NCAA introuvable"},404);
      if(!["committed","active"].includes(String(cs.data.status||"")))return h({error:"Le joueur n’est pas actuellement engagé en NCAA."},409);
      const today=String(career.data.career_date||new Date().toISOString().slice(0,10));
      const endSeason=String(new Date(today+"T12:00:00Z").getUTCFullYear());
      const school=String(cs.data.team?.name||"Université");
      const [stateUp,playerUp,ncaaUp]=await Promise.all([
        db.from("college_career_state").update({status:"pro"}).eq("id","demo"),
        db.from("players").update({
          ncaa_current:false,ncaa_status:"Alumni",ncaa_last_school:school,ncaa_verified:true,ncaa_school:null,ncaa_rank:null
        }).eq("id",managedId),
        db.from("ncaa_career").upsert({
          player_id:managedId,school,division:"NCAA Division I",end_season:endSeason,status:"Alumni",
          departure_date:today,verified:true,source_label:"Court Boss save · passage pro enregistré",
          last_verified_at:new Date().toISOString()
        },{onConflict:"player_id"})
      ]);
      const err=stateUp.error||playerUp.error||ncaaUp.error;if(err)return h({error:err.message},500);
      await db.from("inbox_items").insert({kind:"college",title:"Passage professionnel",body:String(career.data.player_name||"Le joueur")+" quitte "+school+" pour passer professionnel. Son historique NCAA reste archivé.",action_route:"university",is_read:false});
      return h({ok:true,status:"pro",ncaa_status:"Alumni",school,departure_date:today});
    }

    if(action==="play_college_dual"){
      const dual=await db.from("college_duals").select("*,home:college_teams!college_duals_home_team_id_fkey(*),away:college_teams!college_duals_away_team_id_fkey(*)").eq("id",id).maybeSingle();
      if(dual.error||!dual.data)return h({error:dual.error?.message||"Dual not found"},404);
      if(dual.data.status==="completed")return h({ok:true,home_score:dual.data.home_score,away_score:dual.data.away_score,already:true});
      const hs=3+((id*7)%5),as=3+((id*11)%5);
      const homeScore=hs===as?4:Math.min(7,hs),awayScore=hs===as?3:Math.min(7,as);
      const up=await db.from("college_duals").update({home_score:homeScore,away_score:awayScore,status:"completed"}).eq("id",id);
      if(up.error)return h({error:up.error.message},500);
      const cs=await db.from("college_career_state").select("*").eq("id","demo").maybeSingle();
      if(cs.data?.status==="committed"){
        await db.from("college_career_state").update({coach_trust:Math.min(100,Number(cs.data.coach_trust||55)+3),academic_progress:Math.min(100,Number(cs.data.academic_progress||72)+1)}).eq("id","demo");
      }
      return h({ok:true,home_score:homeScore,away_score:awayScore});
    }


    if(action==="play_davis_tie"){
      const tie=await db.from("davis_ties").select("*").eq("id",id).maybeSingle();
      if(tie.error||!tie.data)return h({error:tie.error?.message||"Tie not found"},404);
      if(tie.data.status==="completed"){
        const rub=await db.from("davis_rubbers").select("*").eq("tie_id",id).order("rubber_no");
        return h({ok:true,already:true,tie:tie.data,rubbers:rub.data??[]});
      }
      const home=String(tie.data.home_nation||"").toUpperCase(),away=String(tie.data.away_nation||"").toUpperCase();
      if(!home||!away||home==="TBD"||away==="TBD")return h({error:"Affiche Davis pas encore déterminée."},409);

      const playerSelect="id,name,country,ranking,doubles_ranking,current_ability,form,fitness,fatigue,player_attributes(hard_affinity,clay_affinity,grass_affinity,doubles)";
      const [homeRes,awayRes,homeSquad,awaySquad]=await Promise.all([
        db.from("players").select(playerSelect).eq("ranking_current",true).eq("country",home).order("ranking").limit(6),
        db.from("players").select(playerSelect).eq("ranking_current",true).eq("country",away).order("ranking").limit(6),
        db.from("davis_squad").select("role,players("+playerSelect+")").eq("nation",home),
        db.from("davis_squad").select("role,players("+playerSelect+")").eq("nation",away)
      ]);
      const err=homeRes.error||awayRes.error||homeSquad.error||awaySquad.error;
      if(err)return h({error:err.message},500);
      const flatten=(x:any)=>({...x,player_attributes:Array.isArray(x.player_attributes)?x.player_attributes[0]:x.player_attributes});
      const squad=(rows:any[],fallback:any[])=>{
        const assigned=(rows??[]).map((x:any)=>({role:x.role,p:flatten(Array.isArray(x.players)?x.players[0]:x.players)})).filter((x:any)=>x.p?.id);
        const role=(r:string)=>assigned.find((x:any)=>x.role===r)?.p;
        const base=(fallback??[]).map(flatten);
        return {
          s1:role("Simple 1")||base[0],
          s2:role("Simple 2")||base[1]||base[0],
          d1:role("Double A")||base.find((p:any)=>p.doubles_ranking)||base[0],
          d2:role("Double B")||base.filter((p:any)=>p.doubles_ranking)[1]||base[1]||base[0]
        };
      };
      const H=squad(homeSquad.data??[],homeRes.data??[]),A=squad(awaySquad.data??[],awayRes.data??[]);
      if(!H.s1||!H.s2||!A.s1||!A.s2)return h({error:"Sélection Davis incomplète pour "+home+" ou "+away},409);

      const surf=String(tie.data.surface||"Dur");
      const key=surf.includes("Terre")?"clay_affinity":surf.includes("Gazon")?"grass_affinity":"hard_affinity";
      const strength=(p:any)=>Number(p.current_ability||50)+Number(p.form||70)*.18+Number(p.fitness||85)*.08-Number(p.fatigue||20)*.12+Number(p.player_attributes?.[key]||10)*.7;
      const one=(ha:any,aa:any)=>{const prob=1/(1+Math.exp(-(strength(ha)-strength(aa))/7));const hw=Math.random()<prob;return {winner:hw?home:away,score:Math.abs(strength(ha)-strength(aa))<7?"7-6 4-6 6-3":(hw?"6-3 6-4":"4-6 3-6")}};
      const pair=(a:any,b:any)=>strength(a)*.46+strength(b)*.46+Number(a.player_attributes?.doubles||10)*.35+Number(b.player_attributes?.doubles||10)*.35;
      const dbl=(ha:any,hb:any,aa:any,ab:any)=>{const ph=pair(ha,hb),pa=pair(aa,ab),prob=1/(1+Math.exp(-(ph-pa)/8));const hw=Math.random()<prob;return {winner:hw?home:away,score:Math.abs(ph-pa)<7?"7-6 3-6 6-4":(hw?"6-4 6-3":"4-6 3-6")}};

      const rubs:any[]=[];
      const push=(no:number,type:string,hn:string,an:string,res:any)=>rubs.push({tie_id:id,rubber_no:no,rubber_type:type,home_names:hn,away_names:an,winner_nation:res.winner,score:res.score});
      push(1,"Simple",H.s1.name,A.s2.name,one(H.s1,A.s2));
      push(2,"Simple",H.s2.name,A.s1.name,one(H.s2,A.s1));
      push(3,"Double",H.d1.name+" / "+H.d2.name,A.d1.name+" / "+A.d2.name,dbl(H.d1,H.d2,A.d1,A.d2));
      let hs=rubs.filter(x=>x.winner_nation===home).length,as=rubs.filter(x=>x.winner_nation===away).length;
      if(hs<3&&as<3){push(4,"Simple",H.s1.name,A.s1.name,one(H.s1,A.s1));hs=rubs.filter(x=>x.winner_nation===home).length;as=rubs.filter(x=>x.winner_nation===away).length;}
      if(hs<3&&as<3){push(5,"Simple",H.s2.name,A.s2.name,one(H.s2,A.s2));hs=rubs.filter(x=>x.winner_nation===home).length;as=rubs.filter(x=>x.winner_nation===away).length;}

      const del=await db.from("davis_rubbers").delete().eq("tie_id",id);
      if(del.error)return h({error:del.error.message},500);
      const ins=await db.from("davis_rubbers").insert(rubs);
      if(ins.error)return h({error:ins.error.message},500);
      const up=await db.from("davis_ties").update({status:"completed",home_score:hs,away_score:as}).eq("id",id);
      if(up.error)return h({error:up.error.message},500);
      const winnerNation=hs>as?home:away;
      const stage=String(tie.data.stage||"");
      if(stage==="Final 8 · Quarter-final"){
        const semis=await db.from("davis_ties").select("*").in("stage",["Final 8 · Semi-final 1","Final 8 · Semi-final 2"]).order("tie_date");
        if(!semis.error){
          const s1=(semis.data??[]).find((x:any)=>x.stage==="Final 8 · Semi-final 1");
          const s2=(semis.data??[]).find((x:any)=>x.stage==="Final 8 · Semi-final 2");
          if(home==="CZE"&&away==="CAN"&&s1)await db.from("davis_ties").update({away_nation:winnerNation}).eq("id",s1.id);
          if(home==="ITA"&&away==="KOR"&&s1)await db.from("davis_ties").update({home_nation:winnerNation}).eq("id",s1.id);
          if(home==="GBR"&&away==="GER"&&s2)await db.from("davis_ties").update({home_nation:winnerNation}).eq("id",s2.id);
          if(home==="AUT"&&away==="ESP"&&s2)await db.from("davis_ties").update({away_nation:winnerNation}).eq("id",s2.id);
        }
      }else if(stage==="Final 8 · Semi-final 1"||stage==="Final 8 · Semi-final 2"){
        const fin=await db.from("davis_ties").select("*").eq("stage","Final 8 · Final").maybeSingle();
        if(!fin.error&&fin.data){
          const patch=stage.endsWith("1")?{home_nation:winnerNation}:{away_nation:winnerNation};
          await db.from("davis_ties").update(patch).eq("id",fin.data.id);
        }
      }
      await db.from("inbox_items").insert({kind:"davis",title:"Résultat Coupe Davis",body:home+" "+hs+"-"+as+" "+away+".",action_route:"davis",is_read:false});
      return h({ok:true,tie:{...tie.data,status:"completed",home_score:hs,away_score:as},rubbers:rubs,winner_nation:winnerNation});
    }

    if(action==="set_scouting_assignment"){
      const focus=String(body?.focus||"U23 potentiel").slice(0,80);
      const up=await db.from("scouting_assignments").update({focus,progress:0,status:"active",started_at:new Date().toISOString().slice(0,10)}).eq("id",id);
      if(up.error)return h({error:up.error.message},500);
      await db.from("inbox_items").insert({kind:"scouting",title:"Nouvelle mission scouting",body:"Mission lancée : "+focus+".",action_route:"scouting",is_read:false});
      return h({ok:true,focus});
    }


    if(action==="request_wildcard"){
      const [t,a]=await Promise.all([
        db.from("tournaments").select("*").eq("id",id).maybeSingle(),
        db.from("academies").select("reputation").eq("id","demo").maybeSingle()
      ]);
      if(t.error||a.error||!t.data)return h({error:(t.error||a.error)?.message||"Tournoi introuvable"},404);
      const rank=Number(career.data.singles_rank||9999),qual=Number(t.data.qual_cut||t.data.direct_cut||rank);
      const rep=Number(a.data?.reputation||48);
      const proximity=Math.max(0,35-Math.max(0,rank-qual)/12);
      const score=Math.round(rep*.65+proximity+Math.random()*22);
      const status=score>=58?"accepted":"declined";
      const up=await db.from("wildcard_requests").upsert({tournament_id:id,status,decision_score:score,created_at:new Date().toISOString()},{onConflict:"tournament_id"}).select("*").single();
      if(up.error)return h({error:up.error.message},500);
      await db.from("inbox_items").insert({kind:"tournament",title:"Décision wild card",body:(status==="accepted"?"Wild card accordée pour ":"Wild card refusée pour ")+t.data.name+".",action_route:"calendar",is_read:false});
      return h({ok:true,status,score});
    }


    if(action==="edit_career"){
      const field=String(body?.field||"");
      const allowed=["player_name","country","style","age","height_cm","weight_kg"];
      if(!allowed.includes(field))return h({error:"Champ non modifiable"},400);
      let value:any=body?.value;
      if(["age","height_cm","weight_kg"].includes(field))value=n(value,0,1,250);
      else value=String(value??"").trim().slice(0,80);
      const up:any={updated_at:new Date().toISOString()};up[field]=value;
      const cu=await db.from("career_state").update(up).eq("id","demo");
      if(cu.error)return h({error:cu.error.message},500);
      const pu:any={};
      if(field==="player_name")pu.name=value;
      if(field==="country")pu.country=value;
      if(field==="style")pu.style=value;
      if(field==="age")pu.age=value;
      if(field==="height_cm")pu.height_cm=value;
      if(field==="weight_kg")pu.weight_kg=value;
      if(Object.keys(pu).length){
        const managed=await db.from("career_state").select("managed_player_id").eq("id","demo").maybeSingle();
        if(managed.error||!managed.data?.managed_player_id)return h({error:managed.error?.message||"Managed player missing"},500);
        const p=await db.from("players").update(pu).eq("id",managed.data.managed_player_id);
        if(p.error)return h({error:p.error.message},500);
      }
      return h({ok:true,field,value});
    }


    if(action==="upgrade_facility"){
      const fac=await db.from("facilities").select("*").eq("id",id).maybeSingle();
      if(fac.error||!fac.data)return h({error:fac.error?.message||"Installation introuvable"},404);
      const level=Number(fac.data.level||1);
      if(level>=5)return h({error:"Installation déjà au maximum"},409);
      const cost=level*3500;
      if(Number(career.data.budget||0)<cost)return h({error:"Budget insuffisant"},409);
      const budget=Number(career.data.budget||0)-cost;
      const fup=await db.from("facilities").update({level:level+1}).eq("id",id);
      if(fup.error)return h({error:fup.error.message},500);
      const cup=await db.from("career_state").update({budget,updated_at:new Date().toISOString()}).eq("id","demo");
      if(cup.error)return h({error:cup.error.message},500);
      await db.from("inbox_items").insert({kind:"academy",title:"Installation améliorée",body:String(fac.data.name||"Installation")+" passe niveau "+(level+1)+".",action_route:"academy",is_read:false});
      return h({ok:true,level:level+1,cost,budget});
    }



    if(action==="create_custom_player"){
      const name=String(body?.name||"").trim().slice(0,60);
      const country=String(body?.country||"FRA").trim().toUpperCase().slice(0,3);
      const age=n(body?.age,18,15,35);
      const handedness=["Droitier","Gaucher"].includes(String(body?.handedness))?String(body.handedness):"Droitier";
      const backhand=["1 main","2 mains"].includes(String(body?.backhand))?String(body.backhand):"2 mains";
      const style=String(body?.style||"All-court").slice(0,60);
      const tier=String(body?.tier||"ITF");
      const potential=n(body?.potential,82,55,99);
      if(name.length<2)return h({error:"Nom trop court"},400);

      const tierMap:any={
        "Débutant":{rank:1800,points:4,ca:42},
        "ITF":{rank:1200,points:20,ca:50},
        "Challenger":{rank:650,points:75,ca:58},
        "Espoir":{rank:350,points:160,ca:65}
      };
      const t=tierMap[tier]||tierMap["ITF"];
      const ca=Math.min(Number(t.ca),potential);
      const slug="custom-"+Date.now()+"-"+Math.floor(Math.random()*100000);

      const ins=await db.from("players").insert({
        slug,name,country,is_real:false,ranking:t.rank,source_ranking:null,points:t.points,
        doubles_ranking:1800,itf_ranking:t.rank>900?Math.max(1,t.rank-300):null,junior_ranking:age<=18?Math.max(1,Math.round(t.rank/4)):null,
        age,height_cm:n(body?.height_cm,184,155,215),weight_kg:n(body?.weight_kg,78,45,130),
        handedness,backhand,style,current_ability:ca,potential,
        form:70,fitness:92,morale:80,fatigue:10,scouting_confidence:100,injury_status:"Fit",
        data_source:"User-created Court Boss player",data_snapshot:new Date().toISOString().slice(0,10),ranking_current:false
      }).select("id,name,country,ranking,current_ability,potential").single();
      if(ins.error)return h({error:ins.error.message},500);

      const idp=Number(ins.data.id);
      let base=Math.max(5,Math.min(18,Math.round(ca/6)));
      const A=(salt:number,bonus=0)=>Math.max(3,Math.min(20,base+((idp*salt)%5)-2+bonus));
      const isServer=/serveur|service/i.test(style),isCounter=/contre/i.test(style),isAll=/all-court|polyvalent/i.test(style),isClay=/terre/i.test(style),isAttack=/attaquant/i.test(style);
      const attrs:any={
        player_id:idp,
        serve_power:A(3,isServer?4:isAttack?2:0),
        serve_precision:A(5,isServer?3:0),
        forehand:A(7,isAttack?3:isClay?2:0),
        backhand:A(11,isCounter?2:0),
        return_game:A(13,isCounter?4:0),
        volley:A(17,isAll?3:isAttack?1:0),
        touch:A(19,isAll?2:0),
        movement:A(23,isCounter?3:isClay?2:0),
        speed:A(29,isCounter?2:0),
        stamina:A(31,isClay?3:0),
        strength:A(37,isServer?3:isAttack?2:0),
        anticipation:A(41,isCounter?3:0),
        concentration:A(43,1),
        composure:A(47,isAll?2:0),
        fighting_spirit:A(53,1),
        tactics:A(59,isAll?3:isCounter?2:0),
        doubles:A(61,isAll?2:0),
        clay_affinity:A(67,isClay?5:0),
        hard_affinity:A(71,isServer||isAttack?3:1),
        grass_affinity:A(73,isServer||isAll?4:0)
      };
      const ai=await db.from("player_attributes").insert(attrs);
      if(ai.error)return h({error:ai.error.message},500);

      return h({ok:true,player:ins.data,slug});
    }

    if(action==="take_over_player"){
      const [target,previousCareer]=await Promise.all([
        db.from("players").select("*,player_attributes(*)").eq("id",id).maybeSingle(),
        db.from("career_state").select("managed_player_id").eq("id","demo").maybeSingle()
      ]);
      if(target.error||previousCareer.error||!target.data)return h({error:(target.error||previousCareer.error)?.message||"Joueur introuvable"},404);
      const p:any=target.data;
      const attrs:any=Array.isArray(p.player_attributes)?p.player_attributes[0]:p.player_attributes||{};
      const startDate=String(body?.date||"2026-09-27").slice(0,10);
      const basePoints=Math.max(0,Number(p.points||0));
      const baseDoubleRank=Math.max(1,Number(p.doubles_ranking||1800));
      const baseDoublePoints=Math.max(0,Math.round(45*(1800/baseDoubleRank-1)));

      await Promise.all([
        db.from("tournament_runs").delete().gte("id",0),
        db.from("doubles_runs").delete().gte("id",0),
        db.from("match_history").delete().eq("user_involved",true),
        db.from("wildcard_requests").delete().gte("id",0),
        db.from("shortlist").delete().gte("player_id",0),
        db.from("user_ranking_points").delete().eq("owner_id","demo"),
        db.from("user_doubles_points").delete().eq("owner_id","demo"),
        db.from("user_training_progress").update({xp:0,updated_at:new Date().toISOString()}).neq("attribute","")
      ]);

      await db.from("user_ranking_points").insert({
        owner_id:"demo",label:"Points de départ - "+p.name,earned_date:startDate,
        expiry_date:(()=>{const d=new Date(startDate+"T12:00:00Z");d.setUTCDate(d.getUTCDate()+364);return d.toISOString().slice(0,10)})(),
        points:basePoints,active:true
      });
      await db.from("user_doubles_points").insert({
        owner_id:"demo",label:"Points double de départ - "+p.name,earned_date:startDate,
        expiry_date:(()=>{const d=new Date(startDate+"T12:00:00Z");d.setUTCDate(d.getUTCDate()+364);return d.toISOString().slice(0,10)})(),
        points:baseDoublePoints,active:true,partner_id:null
      });

      const careerUpdate={
        managed_player_id:p.id,
        player_name:p.name,country:p.country,career_date:startDate,week:1,
        singles_rank:Number(p.ranking||2000),doubles_rank:baseDoubleRank,points:basePoints,doubles_points:baseDoublePoints,
        age:Number(p.age||19),height_cm:Number(p.height_cm||184),weight_kg:Number(p.weight_kg||78),
        handedness:String(p.handedness||"Droitier"),backhand:String(p.backhand||"2 mains"),
        current_ability:Number(p.current_ability||55),potential:Number(p.potential||75),
        form:Number(p.form||70),fitness:Number(p.fitness||90),morale:Number(p.morale||75),fatigue:Number(p.fatigue||15),
        budget:14800,style:String(p.style||"All-court"),injury_status:"Fit",updated_at:new Date().toISOString()
      };
      const cu=await db.from("career_state").update(careerUpdate).eq("id","demo");
      if(cu.error)return h({error:cu.error.message},500);

      const previousId=Number(previousCareer.data?.managed_player_id||0);
      if(previousId && previousId!==Number(p.id)){
        const prev=await db.from("players").select("id,is_real").eq("id",previousId).maybeSingle();
        if(!prev.error&&prev.data&&!prev.data.is_real){
          await db.from("players").update({ranking_current:false}).eq("id",previousId);
        }
      }

      if(!p.ranking_current){
        const activate=await db.from("players").update({ranking_current:true}).eq("id",p.id);
        if(activate.error)return h({error:activate.error.message},500);
      }

      const currentCount=await db.from("players").select("id",{count:"exact",head:true}).eq("ranking_current",true).lte("ranking",3000);
      const overflow=Math.max(0,Number(currentCount.count||0)-3000);
      if(overflow>0){
        const tail=await db.from("players").select("id").eq("ranking_current",true).neq("id",p.id).lte("ranking",3000).order("ranking",{ascending:false}).order("id",{ascending:false}).limit(overflow);
        if(!tail.error&&(tail.data??[]).length){
          await db.from("players").update({ranking_current:false,ranking_source:"Displaced by managed-player career slot"}).in("id",(tail.data??[]).map((x:any)=>x.id));
        }
      }

      await db.from("finances").update({prize_money:0,sponsor_income:0,travel_cost:0,staff_cost:0}).eq("id","demo");
      await db.from("news_items").insert({body:"Nouvelle carrière lancée avec "+p.name+"."});
      return h({ok:true,player:{id:p.id,name:p.name,country:p.country,ranking:p.ranking},career:careerUpdate});
    }


    if(action==="academy_focus"){
      const focus=String(body?.focus||"Équilibré").slice(0,60);
      const up=await db.from("academy_roster").update({development_focus:focus}).eq("id",id).eq("status","active");
      if(up.error)return h({error:up.error.message},500);
      return h({ok:true,focus});
    }

    if(action==="renew_academy_player"){
      const row=await db.from("academy_roster").select("*,players(name)").eq("id",id).maybeSingle();
      if(row.error||!row.data)return h({error:row.error?.message||"Joueur académie introuvable"},404);
      const end=new Date(String(row.data.contract_end)+"T12:00:00Z");end.setUTCFullYear(end.getUTCFullYear()+1);
      const weekly=Math.round(Number(row.data.weekly_cost||100)*1.08);
      const up=await db.from("academy_roster").update({contract_end:end.toISOString().slice(0,10),weekly_cost:weekly}).eq("id",id);
      if(up.error)return h({error:up.error.message},500);
      await db.from("contracts").update({end_date:end.toISOString().slice(0,10),weekly_salary:weekly})
        .eq("subject_type","player").eq("subject_name",row.data.players?.name||"");
      return h({ok:true,end_date:end.toISOString().slice(0,10),weekly_cost:weekly});
    }

    if(action==="release_academy_player"){
      const row=await db.from("academy_roster").select("*,players(name)").eq("id",id).maybeSingle();
      if(row.error||!row.data)return h({error:row.error?.message||"Joueur académie introuvable"},404);
      if(row.data.squad_role==="Joueur principal")return h({error:"Le joueur principal ne peut pas être libéré depuis cet écran."},409);
      const up=await db.from("academy_roster").update({status:"released"}).eq("id",id);
      if(up.error)return h({error:up.error.message},500);
      await db.from("contracts").update({status:"terminated"}).eq("subject_type","player").eq("subject_name",row.data.players?.name||"");
      await db.from("inbox_items").insert({kind:"academy",title:"Joueur libéré",body:(row.data.players?.name||"Le joueur")+" quitte l’académie.",action_route:"academy",is_read:false});
      return h({ok:true,status:"released"});
    }


    if(action==="set_medical_protocol"){
      const protocol=String(body?.protocol||"Récupération active");
      const plans:any={
        "Repos complet":{physio_hours:1,weekly_cost:0,notes:"Repos complet, priorité à la récupération"},
        "Physio intensive":{physio_hours:8,weekly_cost:900,notes:"Traitement intensif avec objectif de retour accéléré"},
        "Récupération active":{physio_hours:2,weekly_cost:250,notes:"Récupération active et suivi médical"},
        "Maintien de forme":{physio_hours:1,weekly_cost:120,notes:"Maintien de charge, risque de rechute plus élevé"}
      };
      if(!plans[protocol])return h({error:"Protocole médical inconnu"},400);
      const cfg=plans[protocol];
      const up=await db.from("medical_plan").upsert({id:"demo",protocol,...cfg,updated_at:new Date().toISOString()},{onConflict:"id"}).select("*").single();
      if(up.error)return h({error:up.error.message},500);
      if(career.data.managed_player_id){
        await db.from("injuries").update({treatment:protocol}).eq("player_id",career.data.managed_player_id).eq("status","Active");
      }
      await db.from("inbox_items").insert({kind:"medical",title:"Plan médical mis à jour",body:"Protocole : "+protocol+".",action_route:"medical",is_read:false});
      return h({ok:true,plan:up.data});
    }

    if(action==="mark_inbox_read"){
      const up=await db.from("inbox_items").update({is_read:true}).eq("id",id);
      return up.error?h({error:up.error.message},500):h({ok:true});
    }

    return h({error:"Unknown action"},400);
  }


  if(path.endsWith("/api/countries")&&req.method==="GET"){
    const rows=await db.from("country_player_counts").select("*").order("players",{ascending:false});
    if(rows.error)return h({error:rows.error.message},500);
    return h({rows:(rows.data??[]).map((x:any)=>({...x,continent:continentOf(x.country)}))});
  }


  if((path.endsWith("/api/history-leaders")||path.endsWith("/api/history-hub"))&&req.method==="GET"){
    const country=(u.searchParams.get("country")??"").trim().toUpperCase().slice(0,3);
    const continent=(u.searchParams.get("continent")??"").trim().slice(0,40);
    const limit=n(u.searchParams.get("limit"),80,1,200);
    const career=await db.from("career_state").select("career_date").eq("id","demo").maybeSingle();
    const gameDate=String(career.data?.career_date||"2026-09-27");

    const [historyRows,youthRows,ncaaRows] = await Promise.all([
      db.from("history_player_scores").select("*").order("history_score",{ascending:false}).limit(1500),
      db.from("players")
        .select("id,name,country,birth_date,age,ranking,points,junior_ranking,junior_points,itf_ranking,current_ability,potential,photo_url,game_generated,generated_year,ncaa_current,ncaa_school,career_status,data_source")
        .not("birth_date","is",null)
        .or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*")
        .order("ranking",{ascending:true,nullsFirst:false})
        .limit(2500),
      db.from("ncaa_player_registry").select("player_id,status,season,ita_rank,school,division,snapshot_date")
        .order("snapshot_date",{ascending:false}).limit(5000)
    ]);
    const err=historyRows.error||youthRows.error||ncaaRows.error;
    if(err)return h({error:err.message},500);

    const allHistory=(historyRows.data??[]).map((x:any)=>({...x,continent:continentOf(x.country)}));
    let pool=allHistory;
    if(country)pool=pool.filter((x:any)=>x.country===country);
    if(continent)pool=pool.filter((x:any)=>x.continent===continent);

    const countryBest:any[]=[];
    const seenCountry=new Set<string>();
    for(const x of allHistory){
      if(!seenCountry.has(x.country)){seenCountry.add(x.country);countryBest.push(x);}
    }
    const continentBest:any[]=[];
    const seenContinent=new Set<string>();
    for(const x of allHistory){
      if(!seenContinent.has(x.continent)){seenContinent.add(x.continent);continentBest.push(x);}
    }

    const hallOfFame=allHistory
      .filter((x:any)=>Number(x.grand_slams||0)>=1||Number(x.titles||0)>=25||Number(x.wins||0)>=500)
      .slice(0,40);
    const grandSlamRecords=[...allHistory]
      .sort((a:any,b:any)=>Number(b.grand_slams||0)-Number(a.grand_slams||0)||Number(b.titles||0)-Number(a.titles||0)||Number(b.history_score||0)-Number(a.history_score||0))
      .slice(0,30);

    const nationalPool=country?allHistory.filter((x:any)=>x.country===country):pool;
    const bestBy=(field:string)=>[...nationalPool].sort((a:any,b:any)=>Number(b[field]||0)-Number(a[field]||0)||Number(b.history_score||0)-Number(a.history_score||0))[0]||null;
    const nationalRecords={
      grand_slams:bestBy("grand_slams"),
      titles:bestBy("titles"),
      wins:bestBy("wins"),
      win_pct:[...nationalPool].filter((x:any)=>Number(x.wins||0)+Number(x.losses||0)>=50).sort((a:any,b:any)=>Number(b.win_pct||0)-Number(a.win_pct||0))[0]||null
    };

    const ageRows=(youthRows.data??[]).map((p:any)=>({...p,age:ageAt(p.birth_date,gameDate,p.age,p.age_snapshot_date),continent:continentOf(p.country)}));
    const youthFilter=(maxAge:number)=>ageRows.filter((p:any)=>{
      if(Number(p.age)>maxAge)return false;
      if(country&&p.country!==country)return false;
      if(continent&&p.continent!==continent)return false;
      return String(p.career_status||"active")!=="retired";
    });
    const youthSort=(a:any,b:any)=>{
      const ar=a.ranking!=null?Number(a.ranking):10000+(a.junior_ranking!=null?Number(a.junior_ranking):5000);
      const br=b.ranking!=null?Number(b.ranking):10000+(b.junior_ranking!=null?Number(b.junior_ranking):5000);
      return ar-br||Number(b.current_ability||0)-Number(a.current_ability||0)||Number(b.potential||0)-Number(a.potential||0);
    };
    const u18=youthFilter(18).sort(youthSort).slice(0,40);
    const u21=youthFilter(21).sort(youthSort).slice(0,60);

    const ncaaProfiles=new Set((ncaaRows.data??[]).map((x:any)=>Number(x.player_id)));
    const ncaaActive=new Set((ncaaRows.data??[]).filter((x:any)=>x.status==="Active").map((x:any)=>Number(x.player_id)));

    return h({
      methodology:"Indice Court Boss: 10 000/Grand Chelem + 2 200/ATP Finals + 1 200/Masters + 180/autre titre + 2/victoire enregistrée. Ce n'est pas un classement officiel du GOAT.",
      filters:{country:country||null,continent:continent||null},
      rows:pool.slice(0,limit),
      countryBest:countryBest.slice(0,100),
      continentBest,
      hallOfFame,
      grandSlamRecords,
      nationalRecords,
      u18,u21,
      coverage:{
        players:pool.length,
        historicalPlayers:allHistory.length,
        countries:new Set(allHistory.map((x:any)=>x.country)).size,
        ncaaProfiles:ncaaProfiles.size,
        ncaaActive:ncaaActive.size,
        gameDate
      }
    });
  }

  if(path.endsWith("/api/world")&&req.method==="GET"){
    const [
      playersTotal,atp,itf,junior,tours,realTours,atpTours,challengerTours,itfTours,fedTours,juniorTours,ncaaTours,
      ncaaTeams,ncaaPlayers,ncaaRegistry,newgens,realPlayers,searchableReal,ageKnownReal,currentMissingAge,currentMissingDob,
      active2025,doublesReal,doublesIndexed,raceReal,nextgenReal,juniorReal,backhandAll,backhandVerified,realDobKnown,estimatedAgeReal,itfMissingAge,juniorMissingAge,ncaaMissingAge
    ] = await Promise.all([
      db.from("players").select("id",{count:"exact",head:true}).or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*"),
      db.from("players").select("id",{count:"exact",head:true}).eq("ranking_current",true),
      db.from("players").select("id",{count:"exact",head:true}).not("itf_ranking","is",null),
      db.from("players").select("id",{count:"exact",head:true}).not("junior_ranking","is",null).not("junior_source","is",null),
      db.from("tournaments").select("id",{count:"exact",head:true}).eq("is_active",true),
      db.from("tournaments").select("id",{count:"exact",head:true}).eq("is_active",true).eq("is_verified",true),
      db.from("tournaments").select("id",{count:"exact",head:true}).eq("is_active",true).eq("is_verified",true).eq("circuit","ATP"),
      db.from("tournaments").select("id",{count:"exact",head:true}).eq("is_active",true).eq("is_verified",true).eq("circuit","Challenger"),
      db.from("tournaments").select("id",{count:"exact",head:true}).eq("is_active",true).eq("is_verified",true).eq("circuit","ITF"),
      db.from("tournaments").select("id",{count:"exact",head:true}).eq("is_active",true).eq("is_verified",true).eq("circuit","Federation"),
      db.from("tournaments").select("id",{count:"exact",head:true}).eq("is_active",true).eq("is_verified",true).eq("circuit","Junior"),
      db.from("tournaments").select("id",{count:"exact",head:true}).eq("is_active",true).eq("is_verified",true).eq("circuit","NCAA"),
      db.from("college_teams").select("id",{count:"exact",head:true}),
      db.from("players").select("id",{count:"exact",head:true}).eq("ncaa_current",true),
      db.from("ncaa_player_registry").select("player_id,status").limit(5000),
      db.from("players").select("id",{count:"exact",head:true}).eq("game_generated",true),
      db.from("players").select("id",{count:"exact",head:true}).eq("is_real",true),
      db.from("players").select("id",{count:"exact",head:true}).eq("is_real",true).or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*"),
      db.from("players").select("id",{count:"exact",head:true}).eq("is_real",true).not("age","is",null).or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*"),
      db.from("players").select("id",{count:"exact",head:true}).eq("ranking_current",true).is("age",null),
      db.from("players").select("id",{count:"exact",head:true}).eq("ranking_current",true).is("birth_date",null),
      db.from("players").select("id",{count:"exact",head:true}).eq("is_real",true).not("circuits_2025","is",null),
      db.from("players").select("id",{count:"exact",head:true}).not("doubles_source","is",null),
      db.from("players").select("id",{count:"exact",head:true}).not("doubles_ranking","is",null).or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*"),
      db.from("players").select("id",{count:"exact",head:true}).not("race_source","is",null),
      db.from("players").select("id",{count:"exact",head:true}).not("nextgen_source","is",null),
      db.from("players").select("id",{count:"exact",head:true}).not("junior_source","is",null),
      db.from("players").select("id",{count:"exact",head:true}).not("backhand","is",null),
      db.from("players").select("id",{count:"exact",head:true}).eq("backhand_verified",true),
      db.from("players").select("id",{count:"exact",head:true}).eq("is_real",true).not("birth_date","is",null).or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*"),
      db.from("players").select("id",{count:"exact",head:true}).eq("is_real",true).is("birth_date",null).not("age","is",null).or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*"),
      db.from("players").select("id",{count:"exact",head:true}).not("itf_ranking","is",null).is("age",null),
      db.from("players").select("id",{count:"exact",head:true}).not("junior_source","is",null).is("age",null),
      db.from("players").select("id",{count:"exact",head:true}).eq("ncaa_current",true).is("age",null)
    ]);
    return h({
      rankingReferenceDate:"2025-12-01",
      players:atp.count??0,
      playersTotal:playersTotal.count??0,
      realPlayersTotal:realPlayers.count??0,
      searchableRealPlayers:searchableReal.count??0,
      worldRankingCapacity:30000,
      realPlayersWithAge:ageKnownReal.count??0,
      activeRealPlayers2025:active2025.count??0,
      atpRanked:atp.count??0,
      sourcedDoubles:doublesReal.count??0,
      indexedDoubles:doublesIndexed.count??0,
      sourcedRace:raceReal.count??0,
      sourcedNextGen:nextgenReal.count??0,
      sourcedJuniors:juniorReal.count??0,
      itfPlayers:itf.count??0,
      juniorPlayers:junior.count??0,
      ncaaTeams:ncaaTeams.count??0,
      ncaaPlayers:ncaaPlayers.count??0,
      ncaaProfilesTotal:new Set((ncaaRegistry.data??[]).map((x:any)=>Number(x.player_id))).size,
      ncaaActiveProfiles:new Set((ncaaRegistry.data??[]).filter((x:any)=>x.status==="Active").map((x:any)=>Number(x.player_id))).size,
      gameGenerated:newgens.count??0,
      tournaments:tours.count??0,
      verifiedTournaments:realTours.count??0,
      officialATP:atpTours.count??0,
      officialChallenger:challengerTours.count??0,
      officialITF:itfTours.count??0,
      officialFederation:fedTours.count??0,
      officialJunior:juniorTours.count??0,
      officialNCAA:ncaaTours.count??0,
      currentRankedMissingAge:currentMissingAge.count??0,
      currentRankedMissingDob:currentMissingDob.count??0,
      playersWithBackhand:backhandAll.count??0,
      verifiedBackhands:backhandVerified.count??0,
      realPlayersWithDob:realDobKnown.count??0,
      estimatedAgeReal:estimatedAgeReal.count??0,
      itfMissingAge:itfMissingAge.count??0,
      juniorMissingAge:juniorMissingAge.count??0,
      ncaaMissingAge:ncaaMissingAge.count??0
    });
  }

  if(path.endsWith("/api/save")&&req.method==="POST"){
    const sid=saveId(req); if(!sid) return h({error:"Invalid save key"},400);
    let payload:any; try{payload=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const {error}=await db.from("game_saves").upsert({id:sid,payload,updated_at:new Date().toISOString()});
    return error?h({error:error.message},500):h({ok:true});
  }

  return h({error:"Not found"},404);
});
