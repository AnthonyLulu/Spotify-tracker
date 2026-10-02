import { juniorTournamentFormatRule, projectedTournamentCuts, qualifyingSectionPlan, tournamentDoublesDrawConfig, tournamentRoundPrize } from "./tournament-policy.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
const supabaseUrl=Deno.env.get("SUPABASE_URL")!;
const serviceRole=Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const db=createClient(supabaseUrl,serviceRole,{auth:{persistSession:false}});

const cors={
  "Access-Control-Allow-Origin":"*",
  "Access-Control-Allow-Headers":"content-type,x-save-key,x-court-boss-key",
  "Access-Control-Allow-Methods":"GET,POST,OPTIONS",
  "Cache-Control":"no-store"
};
const h=(data:unknown,status=200)=>new Response(JSON.stringify(data),{status,headers:{...cors,"Content-Type":"application/json; charset=utf-8"}});
const n=(v:unknown,d:number,min=0,max=5000)=>{const value=v==null||v===""?d:Number(v);return Math.max(min,Math.min(max,Number.isFinite(value)?value:d));};
const normalizeName=(value:string)=>value.normalize("NFD").replace(/\p{Diacritic}/gu,"").toLowerCase().replace(/[^a-z0-9]+/g," ").trim();
const AGE_REFERENCE_DATE="2025-12-01";
const BASE_CURRENCY="EUR";
const PRIZE_FX_TO_EUR_20251201:Record<string,number>={EUR:1,USD:1/1.1646,GBP:1/0.8778,AUD:1/1.7740};
const prizeFxToEur=(currency:any)=>PRIZE_FX_TO_EUR_20251201[String(currency||"EUR").toUpperCase()]??1;
const prizeToBaseEur=(amount:any,currency:any)=>{
  const value=Number(amount||0);
  if(!Number.isFinite(value))return 0;
  return Math.round(value*prizeFxToEur(currency)*100)/100;
};
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
async function resolveTennisTempleBio(player:any,gameDate:string){
  if(!player?.is_real||!player?.name)return player;
  const observedDate=new Date().toISOString().slice(0,10);
  const needsHeight=!player.height_cm||!player.height_verified;
  const needsAge=!player.birth_date&&(/estimate|estim/i.test(String(player.age_source||""))||player.age==null);
  const needsHand=!player.handedness;
  const needsBackhand=!player.backhand_verified;
  if(!needsHeight&&!needsAge&&!needsHand&&!needsBackhand)return player;
  const slug=normalizeName(String(player.name)).replace(/\s+/g,"-");
  const url="https://en.tennistemple.com/player/"+encodeURIComponent(slug);
  try{
    const r=await fetch(url,{headers:{"User-Agent":"CourtBoss/1.0 (+player-bio-enrichment)","Accept":"text/html"}});
    if(!r.ok)return player;
    const html=await r.text();
    const title=htmlText((html.match(/<h1[^>]*>([\s\S]*?)<\/h1>/i)||[])[1]||"");
    if(title&&normalizeName(title)!==normalizeName(String(player.name)))return player;
    const text=htmlText(html);
    const update:any={};
    const ah=text.match(/Age\s+(\d{1,2})\s*yo\s*\/\s*(\d{3})\s*cm/i)
      || text.match(/Age\s+(\d{1,2}).{0,30}?(\d{3})\s*cm/i);
    if(ah){
      const age=Number(ah[1]),height=Number(ah[2]);
      if(needsAge&&age>=12&&age<=45){
        player.age=age;
        player.age_source="TennisTemple · "+observedDate;
        player.age_snapshot_date=observedDate;
        update.age=age;update.age_source=player.age_source;update.age_snapshot_date=observedDate;
      }
      if(needsHeight&&height>=145&&height<=215){
        player.height_cm=height;
        player.height_verified=true;
        player.height_source="TennisTemple · "+gameDate;
        update.height_cm=height;update.height_verified=true;update.height_source=player.height_source;
      }
    }
    const play=text.match(/Forehand\s+(Right Handed|Left Handed)(?:\s*\(([^)]+)\))?/i);
    if(play){
      if(needsHand){
        player.handedness=/left/i.test(play[1])?"Gaucher":"Droitier";
        update.handedness=player.handedness;
      }
      if(needsBackhand&&play[2]){
        const bh=/double|two/i.test(play[2])?"2 mains":/single|one/i.test(play[2])?"1 main":"";
        if(bh){
          player.backhand=bh;
          player.backhand_verified=true;
          player.backhand_source="TennisTemple · "+gameDate;
          update.backhand=bh;update.backhand_verified=true;update.backhand_source=player.backhand_source;
        }
      }
    }
    if(Object.keys(update).length){
      player.bio_source=[player.bio_source,"TennisTemple"].filter(Boolean).join(" + ");
      update.bio_source=player.bio_source;
      await db.from("players").update(update).eq("id",player.id);
    }
  }catch{}
  return player;
}

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
          return x?.pageprops?.wikibase_item&&(
            title===target ||
            (title.length>=8&&target.length>=8&&(title.includes(target)||target.includes(title)))
          );
        });
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

    if((!player.height_cm||!player.height_verified)&&heightClaim?.amount){
      const amount=Math.abs(Number(heightClaim.amount));
      let cm=0;
      if(amount>1&&amount<3)cm=Math.round(amount*100);
      else if(amount>=100&&amount<230)cm=Math.round(amount);
      if(cm>=140&&cm<=230){
        player.height_cm=cm;
        player.height_verified=true;
        player.height_source="Wikidata "+qid;
        update.height_cm=cm;
        update.height_verified=true;
        update.height_source=player.height_source;
      }
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
  await resolveTennisTempleBio(player,gameDate);
  return player;
}
async function resolvePlayerPhoto(player:any){
  if(!player||!player.is_real||!player.name)return player;

  const update:any={};

  if(!player.wiki_photo_url&&player.photo_url&&/wiki|commons/i.test(String(player.photo_source||""))){
    player.wiki_photo_url=player.photo_url;
    update.wiki_photo_url=player.photo_url;
  }

  if(!player.itf_photo_url&&player.itf_player_id){
    const path=String(player.itf_player_id||"").replace(/^\/+|\/+$/g,"");
    const urls=[
      "https://www.itftennis.com/en/players/"+path+"/mt/s/",
      "https://www.itftennis.com/en/players/"+path+"/jt/s/"
    ];
    for(const profileUrl of urls){
      try{
        const rr=await fetch(profileUrl,{headers:{"User-Agent":"CourtBoss/1.0 (+player-photo-fallback)","Accept":"text/html"}});
        if(!rr.ok)continue;
        const html=await rr.text();
        const m1=html.match(/<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["']/i);
        const m2=html.match(/<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["']/i);
        let raw=String(m1?.[1]||m2?.[1]||"").replace(/&amp;/g,"&").trim();

        if(!raw||/logo|default|placeholder|social-share/i.test(raw)){
          raw="";
          const wanted=normalizeName(String(player.name||""));
          for(const tag of html.match(/<img\b[^>]*>/gi)||[]){
            const alt=String((tag.match(/\balt=["']([^"']+)["']/i)||[])[1]||"").trim();
            if(!alt||normalizeName(alt)!==wanted)continue;
            const src=String((tag.match(/\b(?:data-src|src)=["']([^"']+)["']/i)||[])[1]||"").replace(/&amp;/g,"&").trim();
            if(!src||/logo|default|placeholder|social-share/i.test(src))continue;
            try{raw=new URL(src,profileUrl).toString()}catch{raw=src}
            if(raw)break;
          }
        }

        if(raw&&/^https?:\/\//i.test(raw)&&!/logo|default|placeholder|social-share/i.test(raw)){
          player.itf_photo_url=raw;
          update.itf_photo_url=raw;
          if(!player.photo_url){
            player.photo_url=raw;
            player.photo_source="ITF";
            player.photo_source_url=profileUrl;
            player.photo_source_label="ITF player profile";
            update.photo_url=raw;
            update.photo_source="ITF";
            update.photo_source_url=profileUrl;
            update.photo_source_label=player.photo_source_label;
            update.photo_updated_at=new Date().toISOString();
          }
          break;
        }
      }catch{}
    }
  }

  if(!player.wiki_photo_url&&/^Q\d+$/.test(String(player.wikidata_id||""))){
    try{
      const qid=String(player.wikidata_id);
      const qs=new URLSearchParams({
        action:"wbgetentities",
        ids:qid,
        props:"labels|aliases|claims",
        languages:"en|fr|de|es|it|pt|nl|pl|cs|sr|hr|ru|uk",
        languagefallback:"1",
        format:"json",
        origin:"*"
      });
      const rr=await fetch("https://www.wikidata.org/w/api.php?"+qs.toString(),{
        headers:{"User-Agent":"CourtBoss/1.0 (+safe-wikidata-photo)"}
      });
      if(rr.ok){
        const jj:any=await rr.json();
        const ent=jj?.entities?.[qid];
        if(ent&&!ent.missing){
          const candidates:string[]=[];
          for(const x of Object.values(ent.labels||{}) as any[]){
            if(x?.value)candidates.push(String(x.value));
          }
          for(const arr of Object.values(ent.aliases||{}) as any[]){
            for(const x of (arr||[]))if(x?.value)candidates.push(String(x.value));
          }
          const wanted=normalizeName(String(player.name||"")).replace(/\s+/g,"");
          const nameOk=candidates.some(x=>normalizeName(String(x)).replace(/\s+/g,"")===wanted);

          let dobOk=true;
          const wdTime=String(ent?.claims?.P569?.[0]?.mainsnak?.datavalue?.value?.time||"");
          if(player.birth_date&&/^[-+]\d{4}-\d{2}-\d{2}T/.test(wdTime)){
            dobOk=String(player.birth_date).slice(0,10)===wdTime.replace(/^\+/,"").slice(0,10);
          }

          const file=String(ent?.claims?.P18?.[0]?.mainsnak?.datavalue?.value||"").trim();
          if(nameOk&&dobOk&&file){
            const photo="https://commons.wikimedia.org/wiki/Special:FilePath/"+encodeURIComponent(file)+"?width=640";
            player.wiki_photo_url=photo;
            update.wiki_photo_url=photo;
            if(!player.photo_url){
              player.photo_url=photo;
              player.photo_source="Wikidata/Wikimedia";
              player.photo_source_url="https://www.wikidata.org/wiki/"+qid;
              player.photo_source_label="Wikidata P18 · identité vérifiée";
              update.photo_url=photo;
              update.photo_source="Wikidata/Wikimedia";
              update.photo_source_url=player.photo_source_url;
              update.photo_source_label=player.photo_source_label;
              update.photo_updated_at=new Date().toISOString();
            }
          }
        }
      }
    }catch{}
  }

  if(!player.wiki_photo_url){
    try{
      const qs=new URLSearchParams({
        action:"query",generator:"search",gsrsearch:'"'+String(player.name)+'" tennis',
        gsrnamespace:"0",gsrlimit:"5",prop:"pageimages|info",inprop:"url",piprop:"thumbnail|name",
        pithumbsize:"640",format:"json",origin:"*"
      });
      const r=await fetch("https://en.wikipedia.org/w/api.php?"+qs.toString(),{headers:{"User-Agent":"CourtBoss/1.0"}});
      if(r.ok){
        const j:any=await r.json();
        const pages=(Object.values(j?.query?.pages||{}) as any[]).sort((a:any,b:any)=>Number(a.index??999)-Number(b.index??999));
        const target=normalizeName(String(player.name)).replace(/\s+/g,"");
        const chosen=pages.find((x:any)=>{
          const title=normalizeName(String(x.title||"")).replace(/\s+/g,"");
          return x?.thumbnail?.source&&(
            title===target ||
            (title.length>=8&&target.length>=8&&(title.includes(target)||target.includes(title)))
          );
        });
        const photo=String(chosen?.thumbnail?.source||"").trim();
        if(photo){
          player.wiki_photo_url=photo;
          update.wiki_photo_url=photo;
          if(!player.photo_url){
            player.photo_url=photo;
            player.photo_source="Wikipedia/Wikimedia";
            player.photo_source_url=String(chosen?.fullurl||"");
            update.photo_url=photo;
            update.photo_source="Wikipedia/Wikimedia";
            update.photo_source_url=String(chosen?.fullurl||"");
            update.photo_updated_at=new Date().toISOString();
          }
        }
      }
    }catch{}
  }

  if(Object.keys(update).length){
    update.photo_checked_at=new Date().toISOString();
    try{await db.from("players").update(update).eq("id",player.id)}catch{}
  }
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
const isCurrentJuniorProfile=(p:any)=>{
  if(String(p?.career_status||"active")!=="active")return false;
  const src=String(p?.junior_source||"");
  const age=Number(p?.age);
  if(p?.game_generated===true)return Number.isFinite(age)&&age>=13&&age<=17&&p?.junior_ranking!=null;
  if(p?.is_real===true&&/^CoreTennis/i.test(src))return true;
  return p?.is_real===true&&Number.isFinite(age)&&age>=13&&age<=18&&!!src;
};
const JUNIOR_POOL_SELECT="id,name,name_norm,country,is_real,game_generated,career_status,ranking,source_ranking,game_world_rank,points,ranking_snapshot_date,previous_ranking,rank_change,ranking_previous,ranking_change,best_rank_2025,career_high_rank,career_high_rank_date,weeks_at_no1,weeks_top10,weeks_top100,ranking_history_weeks,ranking_history_source,ranking_history_cutoff,doubles_ranking,doubles_points,doubles_snapshot_date,doubles_source,race_ranking,race_points,race_snapshot_date,race_source,nextgen_ranking,nextgen_points,nextgen_snapshot_date,nextgen_source,nextgen_status,itf_ranking,junior_ranking,junior_points,junior_snapshot_date,junior_source,junior_doubles_ranking,junior_doubles_points,junior_doubles_snapshot_date,junior_doubles_source,age,age_source,age_snapshot_date,birth_date,birth_date_source,height_cm,handedness,backhand,backhand_source,backhand_verified,current_ability,potential,form,fitness,morale,fatigue,style,scouting_confidence,data_source,data_snapshot,ranking_source,ranking_current,photo_url,ncaa_current,ncaa_school,ncaa_division,ncaa_rank,ncaa_status,ncaa_last_school,ncaa_verified";
async function loadJuniorPoolCandidates(rankedOnly=false){
  const all:any[]=[];
  for(let start=0;start<5000;start+=1000){
    let query=db.from("players")
      .select(JUNIOR_POOL_SELECT)
      .not("junior_source","is",null)
      .or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*")
      .order("id",{ascending:true})
      .range(start,start+999);
    if(rankedOnly)query=query.not("junior_ranking","is",null);
    const page=await query;
    if(page.error)throw page.error;
    const rows=page.data??[];
    all.push(...rows);
    if(rows.length<1000)break;
  }
  return all;
}
function cbCsvCells(line:string){
  const out:string[]=[];let cur="";let quoted=false;
  for(let i=0;i<line.length;i++){
    const ch=line[i];
    if(ch==='"'){
      if(quoted&&line[i+1]==='"'){cur+='"';i++}
      else quoted=!quoted;
    }else if(ch===','&&!quoted){out.push(cur);cur=""}
    else cur+=ch;
  }
  out.push(cur);
  return out;
}
function ymdToIso(v:string){
  const s=String(v||"").replace(/[^0-9]/g,"");
  if(s.length!==8)return null;
  return s.slice(0,4)+"-"+s.slice(4,6)+"-"+s.slice(6,8);
}
async function syncSackmannRankingDecade(decade:string,reset=false){
  const allowed=new Set(["70s","80s","90s","00s","10s","20s"]);
  if(!allowed.has(decade))throw new Error("Décennie invalide");
  if(reset){
    const rr=await db.rpc("reset_ranking_career_import");
    if(rr.error)throw rr.error;
  }
  const idsRes=await db.rpc("get_court_boss_sackmann_ids");
  if(idsRes.error)throw idsRes.error;
  const linkedIds=new Set((idsRes.data||[]).map((x:any)=>String(x)));
  const url="https://raw.githubusercontent.com/Aneeshers/tennis-sackmann-archive/main/atp/atp_rankings_"+decade+".csv";
  const res=await fetch(url,{headers:{"User-Agent":"CourtBoss/1.0 (+historical-ranking-sync)","Accept":"text/csv"}});
  if(!res.ok||!res.body)throw new Error("Ranking archive HTTP "+res.status);

  const map=new Map<string,any>();
  let accepted=0;
  let headerSeen=false;
  const processLine=(line:string)=>{
    if(!line)return;
    if(!headerSeen){headerSeen=true;return;}
    const cells=line.split(",");
    if(cells.length<3)return;
    const dateRaw=String(cells[0]||"").trim();
    const rank=Number(cells[1]||0);
    const player=String(cells[2]||"").trim();
    if(!player||!linkedIds.has(player)||!rank||rank<1||dateRaw>"20251201")return;
    const iso=ymdToIso(dateRaw);
    if(!iso)return;
    let a=map.get(player);
    if(!a){
      a={sackmann_id:player,career_high_rank:rank,career_high_rank_date:iso,weeks_at_no1:0,weeks_top10:0,weeks_top100:0,ranking_history_weeks:0,last_date:null,last_rank:null};
      map.set(player,a);
    }
    if(a.last_date&&a.last_rank!=null){
      const prev=Date.parse(a.last_date+"T12:00:00Z");
      const cur=Date.parse(iso+"T12:00:00Z");
      const diffDays=Math.max(1,Math.round((cur-prev)/86400000));
      // Count elapsed ranking weeks through normal 2–6 week publication gaps.
      // Very long suspensions such as the 2020 Covid ranking freeze are not expanded.
      const elapsedWeeks=diffDays>70?1:Math.max(1,Math.round(diffDays/7));
      const lastRank=Number(a.last_rank);
      if(lastRank===1)a.weeks_at_no1+=elapsedWeeks;
      if(lastRank<=10)a.weeks_top10+=elapsedWeeks;
      if(lastRank<=100)a.weeks_top100+=elapsedWeeks;
      a.ranking_history_weeks+=elapsedWeeks;
    }
    if(rank<a.career_high_rank){
      a.career_high_rank=rank;a.career_high_rank_date=iso;
    }else if(rank===a.career_high_rank&&iso<a.career_high_rank_date){
      a.career_high_rank_date=iso;
    }
    a.last_date=iso;
    a.last_rank=rank;
    accepted++;
  };

  const reader=res.body.getReader();
  const decoder=new TextDecoder();
  let carry="";
  while(true){
    const {value,done}=await reader.read();
    if(done)break;
    carry+=decoder.decode(value,{stream:true});
    const lines=carry.split(/\r?\n/);
    carry=lines.pop()||"";
    for(const line of lines)processLine(line);
  }
  carry+=decoder.decode();
  if(carry)processLine(carry);

  for(const a of map.values()){
    if(a.last_rank!=null){
      const lastRank=Number(a.last_rank);
      if(lastRank===1)a.weeks_at_no1++;
      if(lastRank<=10)a.weeks_top10++;
      if(lastRank<=100)a.weeks_top100++;
      a.ranking_history_weeks++;
    }
    delete a.last_date;delete a.last_rank;
  }
  const rows=[...map.values()];
  let linked=0,upserted=0;
  for(let i=0;i<rows.length;i+=400){
    const chunk=rows.slice(i,i+400);
    const r=await db.rpc("apply_ranking_career_decade",{
      p_decade:decade,
      p_rows:chunk,
      p_source:"Jeff Sackmann / Tennis Abstract rankings · elapsed calendar weeks",
      p_cutoff:"2025-12-01"
    });
    if(r.error)throw r.error;
    linked+=Number(r.data?.players_linked||0);
    upserted+=Number(r.data?.rows_upserted||0);
  }
  return {decade,url,lines:accepted,players:rows.length,linked_id_filter:linkedIds.size,aggregates_upserted:upserted,players_linked:linked,cutoff:"2025-12-01",streamed:true,method:"elapsed calendar weeks; long freezes excluded"};
}
async function syncSackmannAtpTitles(fromYear:number,toYear:number){
  const from=Math.max(1968,Math.min(2025,fromYear));
  const to=Math.max(from,Math.min(2025,toYear));
  const out:any[]=[];
  const stats:any[]=[];
  const teamRe=/Davis Cup|United Cup|ATP Cup|Laver Cup|World Team Cup|Hopman/i;
  for(let year=from;year<=to;year++){
    const url="https://raw.githubusercontent.com/Aneeshers/tennis-sackmann-archive/main/atp/atp_matches_"+year+".csv";
    const res=await fetch(url,{headers:{"User-Agent":"CourtBoss/1.0 (+historical-title-sync)","Accept":"text/csv"}});
    if(!res.ok){stats.push({year,ok:false,status:res.status});continue}
    const text=await res.text();
    const lines=text.split(/\r?\n/);
    if(!lines.length)continue;
    const head=cbCsvCells(lines[0]);
    const col=(n:string)=>head.indexOf(n);
    const ix={
      name:col("tourney_name"),surface:col("surface"),level:col("tourney_level"),date:col("tourney_date"),
      winner:col("winner_id"),winnerName:col("winner_name"),winnerCountry:col("winner_ioc"),round:col("round")
    };
    let n=0;
    for(let i=1;i<lines.length;i++){
      const cells=cbCsvCells(lines[i]);
      if(cells.length<head.length-2)continue;
      const round=String(cells[ix.round]||"").trim();
      const name=String(cells[ix.name]||"").trim();
      const levelRaw=String(cells[ix.level]||"").trim();
      const winner=String(cells[ix.winner]||"").trim();
      const dateRaw=String(cells[ix.date]||"").trim();
      if(round!=="F"||!winner||!name||dateRaw>"20251201"||teamRe.test(name))continue;
      if(!["G","M","A","F","O"].includes(levelRaw))continue;
      const titleDate=ymdToIso(dateRaw);if(!titleDate)continue;
      const level=levelRaw==="G"?"Grand Chelem":levelRaw==="M"?"Masters 1000":levelRaw==="F"?"ATP Finals":levelRaw==="O"?"Jeux olympiques":"ATP Tour";
      out.push({
        sackmann_id:winner,
        player_name:String(cells[ix.winnerName]||"").trim()||null,
        country:String(cells[ix.winnerCountry]||"").trim().toUpperCase()||null,
        tournament_name:name,title_date:titleDate,level,
        surface:String(cells[ix.surface]||"").trim()||null,event_type:"singles",source_url:url
      });
      n++;
    }
    stats.push({year,ok:true,titles:n});
  }
  const uniq=[...new Map(out.map((x:any)=>[x.sackmann_id+"|"+x.tournament_name.toLowerCase().replace(/[^a-z0-9]+/g," ")+"|"+x.title_date,x])).values()];
  let imported=0;
  for(let i=0;i<uniq.length;i+=500){
    const r=await db.rpc("import_canonical_atp_titles",{
      p_rows:uniq.slice(i,i+500),
      p_source:"Jeff Sackmann / Tennis Abstract archive · cutoff 2025-12-01"
    });
    if(r.error)throw r.error;
    imported+=Number(r.data?.titles_upserted||0);
  }
  return {from,to,discovered:uniq.length,imported,stats};
}

async function fetchCoreTennisJuniorRows(url:string){
  const res=await fetch(url,{headers:{"User-Agent":"CourtBoss/1.0 (+junior-database-sync)","Accept":"text/html"}});
  if(!res.ok)throw new Error("CoreTennis HTTP "+res.status);
  const html=await res.text();
  const dateRaw=(html.match(/\b([A-Z][a-z]{2}\s+\d{1,2},\s+\d{4})\b/)||[])[1]||"Sep 21, 2026";
  const parsedDate=new Date(dateRaw+" 12:00:00 UTC");
  const snapshot=Number.isNaN(parsedDate.getTime())?"2026-09-21":parsedDate.toISOString().slice(0,10);
  const rows:any[]=[];
  for(const row of html.match(/<tr\b[\s\S]*?<\/tr>/gi)||[]){
    const cells=rowCells(row);
    if(cells.length<2)continue;
    const rank=Number((String(cells[0]?.text||"").match(/^\s*(\d{1,5})\b/)||[])[1]||0);
    const playerCell=String(cells[1]?.text||"").trim();
    const pm=playerCell.match(/^(.+?)\s*\(([A-Z]{3})\)\s*$/);
    if(!rank||!pm)continue;
    const name=pm[1].replace(/\s+/g," ").trim();
    const country=pm[2].toUpperCase();
    if(name.length<3)continue;
    rows.push({ranking:rank,name,country,snapshot,url});
  }
  return rows;
}
async function fetchJuniorTennisDbBirthYears(){
  const url="https://tennisdbjp.com/junior-en/list/wboysrank.html";
  const res=await fetch(url,{headers:{"User-Agent":"CourtBoss/1.0 (+junior-demographics-sync)","Accept":"text/html"}});
  if(!res.ok)throw new Error("Junior Tennis Database HTTP "+res.status);
  const html=await res.text();
  const rows:any[]=[];
  for(const row of html.match(/<tr\b[\s\S]*?<\/tr>/gi)||[]){
    const cells=rowCells(row);
    if(cells.length<3)continue;
    const rank=Number((String(cells[0]?.text||"").match(/\b(\d{1,3})\b/)||[])[1]||0);
    const ym=htmlText(row).match(/\b(200[7-9]|201[0-3])\b/);
    if(!rank||!ym)continue;
    const birth_year=Number(ym[1]);
    const link=row.match(/href=["'][^"']*\/junior-en\/player\/\d+\.html[^"']*["'][^>]*>([\s\S]*?)<\/a>/i)
      || row.match(/href=["'][^"']*\/player\/\d+\.html[^"']*["'][^>]*>([\s\S]*?)<\/a>/i);
    let name=link?htmlText(String(link[1]||"")):String(cells[1]?.text||"").trim();
    name=name.replace(/\b[A-Z]{3}\s*[·•]?\s*(?:200[7-9]|201[0-3])\b/g," ").replace(/\s+/g," ").trim();
    if(!name||name.length<3)continue;
    let country="";
    const last=String(cells[cells.length-1]?.text||"").trim().toUpperCase();
    if(/^[A-Z]{3}$/.test(last))country=last;
    if(!country){
      const pcm=String(cells[1]?.text||"").match(/\b([A-Z]{3})\s*[·•]?\s*(?:200[7-9]|201[0-3])\b/);
      if(pcm)country=pcm[1];
    }
    if(!country){
      const plain=htmlText(row);
      const cms=[...plain.matchAll(/\b([A-Z]{3})\b/g)].map((m:any)=>m[1]);
      country=cms.length?cms[cms.length-1]:"";
    }
    if(!/^[A-Z]{3}$/.test(country))continue;
    rows.push({ranking:rank,name,country,birth_year});
  }
  const dedup=[...new Map(rows.map((x:any)=>[normalizeName(x.name)+"|"+x.country,x])).values()]
    .sort((a:any,b:any)=>a.ranking-b.ranking)
    .slice(0,200);
  return {url,rows:dedup};
}
async function syncJuniorDemographics(){
  const jtd=await fetchJuniorTennisDbBirthYears();
  const applied=await db.rpc("apply_jtd_junior_birth_years",{p_rows:jtd.rows,p_snapshot:"2026-09-21"});
  if(applied.error)throw applied.error;
  const pool=await db.rpc("refresh_junior_display_pool_v3",{p_target:2000});
  if(pool.error)throw pool.error;
  const juniorDoublePool=await db.rpc("refresh_junior_doubles_ranking",{p_snapshot:"2025-12-01"});
  if(juniorDoublePool.error)throw juniorDoublePool.error;
  return {source:jtd.url,parsed:jtd.rows.length,sample:jtd.rows.slice(0,10),apply:applied.data,pool:pool.data,juniorDoubles:juniorDoublePool.data};
}

async function fetchCoreTennisJuniorStatRows(url:string){
  const res=await fetch(url,{headers:{"User-Agent":"CourtBoss/1.0 (+junior-profile-sync)","Accept":"text/html"}});
  if(!res.ok)throw new Error("CoreTennis stats HTTP "+res.status);
  const html=await res.text();
  const rows:any[]=[];
  for(const row of html.match(/<tr\b[\s\S]*?<\/tr>/gi)||[]){
    const cells=rowCells(row);
    if(cells.length<2)continue;
    const playerCell=String(cells[1]?.text||"").trim();
    const pm=playerCell.match(/^(.+?)\s*\(([A-Z]{3})\)\s*$/);
    if(!pm)continue;
    const name=pm[1].replace(/\s+/g," ").trim();
    const country=pm[2].toUpperCase();
    if(name.length<3)continue;
    rows.push({name,country,url});
  }
  return rows;
}
async function scrapeRealJuniorStatProfiles(){
  const snapshot="2026-09-27";
  const sources=[
    "https://www.coretennis.net/majic/pageServer/0l010000m9/en/2026-Junior-Boys-Tennis-Stats.html",
    "https://www.coretennis.net/majic/pageServer/0l010000m9/en/sort/3/2026-Junior-Boys-Tennis-Stats.html",
    "https://www.coretennis.net/majic/pageServer/0l010000m9/en/sort/4/2026-Junior-Boys-Tennis-Stats.html",
    "https://www.coretennis.net/majic/pageServer/0l010000m9/en/sort/5/2026-Junior-Boys-Tennis-Stats.html",
    "https://www.coretennis.net/majic/pageServer/0l010000m9/en/sort/6/2026-Junior-Boys-Tennis-Stats.html",
    "https://www.coretennis.net/majic/pageServer/0l010000m9/en/sort/7/2026-Junior-Boys-Tennis-Stats.html",
    "https://www.coretennis.net/majic/pageServer/0l010000m9/en/sort/8/2026-Junior-Boys-Tennis-Stats.html",
    "https://www.coretennis.net/majic/pageServer/0l010000m9/en/sort/9/2026-Junior-Boys-Tennis-Stats.html"
  ];
  const settled=await Promise.allSettled(sources.map(fetchCoreTennisJuniorStatRows));
  const merged=new Map<string,any>(),stats:any[]=[];
  for(let i=0;i<settled.length;i++){
    const r=settled[i];
    if(r.status==="rejected"){stats.push({url:sources[i],ok:false,error:String((r.reason as any)?.message||r.reason)});continue;}
    stats.push({url:sources[i],ok:true,rows:r.value.length});
    for(const p of r.value){
      const key=normalizeName(p.name)+"|"+p.country;
      if(!merged.has(key))merged.set(key,p);
    }
  }
  const stageRows=[...merged.values()].map((p:any)=>({
    name_norm:normalizeName(p.name),country:p.country,name:p.name,
    snapshot_date:snapshot,source_url:p.url,
    source_label:"CoreTennis 2026 Junior Boys Stats · verified competitor",
    updated_at:new Date().toISOString()
  }));
  for(let i=0;i<stageRows.length;i+=500){
    const up=await db.from("junior_real_profile_staging").upsert(stageRows.slice(i,i+500),{onConflict:"name_norm,country"});
    if(up.error)throw up.error;
  }
  return {snapshot,discovered:merged.size,staged:stageRows.length,sources:stats};
}
async function syncRealJuniorBoys(){
  const sources=[
    "https://www.coretennis.net/majic/pageServer/160101003i/en/ITF-Junior-Boys-Rankings.html",
    "https://www.coretennis.net/majic/pageServer/130100003i/en/ITF-Junior-Boys-Rankings.html",
    "https://www.coretennis.net/majic/pageServer/0n0100005a/en/ITF-Junior-Boys-Best-Progression--Year-.html",
    "https://www.coretennis.net/majic/pageServer/170100003k/en/ITF-Junior-Boys-Best-Progression--Week-.html",
    "https://www.coretennis.net/majic/pageServer/0p0100005b/en/ITF-Junior-Boys-Biggest-Drop--Year-.html",
    "https://www.coretennis.net/majic/pageServer/190100003l/en/ITF-Junior-Boys-Biggest-Drop--Week-.html",
    "https://www.coretennis.net/majic/pageServer/1g010100fn/en/ITF-Junior-Boys-Best-Progression--6-Months-.html",
    "https://www.coretennis.net/majic/pageServer/1i010100fo/en/ITF-Junior-Boys-Biggest-Drop--6-Months-.html"
  ];
  const settled=await Promise.allSettled(sources.map(fetchCoreTennisJuniorRows));
  const merged=new Map<string,any>();
  const sourceStats:any[]=[];
  let snapshot="2026-09-21";
  for(let i=0;i<settled.length;i++){
    const r=settled[i];
    if(r.status==="rejected"){
      sourceStats.push({url:sources[i],ok:false,error:String((r.reason as any)?.message||r.reason)});
      continue;
    }
    if(r.value[0]?.snapshot&&String(r.value[0].snapshot)>snapshot)snapshot=String(r.value[0].snapshot);
    sourceStats.push({url:sources[i],ok:true,rows:r.value.length,snapshot:r.value[0]?.snapshot||null});
    for(const p of r.value){
      const key=normalizeName(p.name)+"|"+p.country;
      const prev=merged.get(key);
      if(!prev||p.ranking<prev.ranking)merged.set(key,p);
    }
  }
  const rows=[...merged.values()].map((p:any)=>({name:p.name,country:p.country,ranking:p.ranking}));
  const sourceLabel="CoreTennis ITF Junior Boys · "+snapshot;
  const bulk=await db.rpc("import_real_junior_rankings",{p_rows:rows,p_source:sourceLabel,p_snapshot:snapshot});
  if(bulk.error)throw bulk.error;
  const [coreReal,legacyReal,generated]=await Promise.all([
    db.from("players").select("id",{count:"exact",head:true})
      .eq("is_real",true).not("junior_ranking","is",null)
      .ilike("junior_source","CoreTennis ITF Junior Boys%"),
    db.from("players").select("id",{count:"exact",head:true})
      .eq("is_real",true).not("junior_ranking","is",null)
      .not("junior_source","ilike","CoreTennis ITF Junior Boys%")
      .gte("age",13).lte("age",18),
    db.from("players").select("id",{count:"exact",head:true})
      .eq("game_generated",true).not("junior_ranking","is",null)
      .not("junior_source","is",null).gte("age",13).lte("age",17)
  ]);
  const realCount=Number(coreReal.count||0)+Number(legacyReal.count||0);
  const generatedCount=Number(generated.count||0);
  const pool=await db.rpc("refresh_junior_display_pool_v3",{p_target:2000});
  if(pool.error)throw pool.error;
  const juniorDoublePool=await db.rpc("refresh_junior_doubles_ranking",{p_snapshot:"2025-12-01"});
  if(juniorDoublePool.error)throw juniorDoublePool.error;
  return {
    sources:sourceStats,
    discovered:merged.size,
    import:bulk.data,
    displayPool:pool.data,
    juniorDoubles:juniorDoublePool.data,
    activeJuniorProfiles:2000,
    realJuniorProfiles:realCount,
    generatedJuniorProfiles:Number(pool.data?.generated_selected||generatedCount)
  };
}
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



async function resolveTournamentImage(t:any){
  if(!t||!t.name)return t;

  // Keep strong tournament/stadium imagery stable, but let generic city/circuit
  // fallbacks upgrade themselves when the public image route is requested.
  // Reject document scans/DJVU false positives that Commons can rank as "images".
  const cachedUrl=String(t.image_url||"");
  const cachedSourceUrl=String(t.image_source_url||"");
  const badImageRe=/\.djvu(?:\/|\.|$|\?)|The_New_York_Times|California_a_guide_to_the_Golden_state|table[_%20 -]?tennis|ping[_%20 -]?pong|pictogram|file-type-icons|fileicon|\.(?:wav|ogg|mp3|flac)(?:$|\?|%)/i;
  const badCachedImage=badImageRe.test(cachedUrl)||badImageRe.test(cachedSourceUrl);
  const weakImage=/Photo de la ville|Fallback circuit|Fallback compétition|Fallback catégorie|réutilisée/i.test(String(t.image_source_label||""))||badCachedImage;
  if(t.image_url&&!weakImage)return t;

  const fallbackImage=weakImage?String(t.image_url||"").trim():"";
  const fallbackSourceUrl=weakImage?String(t.image_source_url||"").trim():"";
  const fallbackSourceLabel=weakImage?String(t.image_source_label||"").trim():"";
  if(weakImage)t.image_url=null;

  const timeoutSignal=()=>AbortSignal.timeout(5000);

  // Tournament feeds often store "venue, city" in the city column. Build
  // geographic candidates once and use the actual city before the venue name.
  const rawPlace=String(t.city||"").trim();
  const usStateCodes:Record<string,string>={
    AL:"Alabama",AK:"Alaska",AZ:"Arizona",AR:"Arkansas",CA:"California",CO:"Colorado",CT:"Connecticut",
    DE:"Delaware",FL:"Florida",GA:"Georgia",HI:"Hawaii",ID:"Idaho",IL:"Illinois",IN:"Indiana",IA:"Iowa",
    KS:"Kansas",KY:"Kentucky",LA:"Louisiana",ME:"Maine",MD:"Maryland",MA:"Massachusetts",MI:"Michigan",
    MN:"Minnesota",MS:"Mississippi",MO:"Missouri",MT:"Montana",NE:"Nebraska",NV:"Nevada",NH:"New Hampshire",
    NJ:"New Jersey",NM:"New Mexico",NY:"New York",NC:"North Carolina",ND:"North Dakota",OH:"Ohio",OK:"Oklahoma",
    OR:"Oregon",PA:"Pennsylvania",RI:"Rhode Island",SC:"South Carolina",SD:"South Dakota",TN:"Tennessee",
    TX:"Texas",UT:"Utah",VT:"Vermont",VA:"Virginia",WA:"Washington",WV:"West Virginia",WI:"Wisconsin",WY:"Wyoming",
    DC:"District of Columbia",PR:"Puerto Rico"
  };
  const usStateNames=new Set(Object.values(usStateCodes).map(x=>normalizeName(x)));
  const facilityRe=/\b(?:arena|stadium|cent(?:er|re)|sports? cent(?:er|re)|tennis cent(?:er|re)|tennis stadium|tennis club|tennis training|tennis academy|country club|golf club|coliseum|club|complex|campus|resort|academy|pavilion|courts?|fairgrounds|olympic park)\b/i;
  const cleanPlace=(value:any)=>String(value||"")
    .replace(/^\s*(?:M15|M25|J30|J60|J100|J200|J300|J500)\s+/i,"")
    .replace(/\s*\((?:cancelled|canceled)\)\s*$/i,"")
    .replace(/\s+(?:Challenger|Classic|International|Trophy|Futures|Open)(?:\s+\d+)?\s*$/i,"")
    .replace(/\s+\d+\s*$/,"")
    .replace(/\s+/g," ").trim();
  const geoCandidates:string[]=[];
  const pushGeo=(value:any)=>{
    const v=cleanPlace(value);
    if(v.length>=3&&!geoCandidates.some(x=>normalizeName(x)===normalizeName(v)))geoCandidates.push(v);
  };

  const parentheticalParts=[...rawPlace.matchAll(/\(([^)]+)\)/g)].map(m=>cleanPlace(m[1])).filter(Boolean);
  const parentheticalVenue=parentheticalParts.find(x=>facilityRe.test(x))||"";
  // Anything in parentheses is metadata/venue/district, never the primary city.
  // Examples: Genoa (Park Tennis Training), Istanbul (Enka), Guangzhou (Huangpu).
  const parenBase=cleanPlace(rawPlace.split("(")[0]);
  const geoRawPlace=cleanPlace(rawPlace.replace(/\([^)]*\)/g," "));
  const commaParts=geoRawPlace.split(",").map(x=>cleanPlace(x)).filter(Boolean);
  const rawFirstPart=cleanPlace(rawPlace.split(",")[0]);
  const venueCandidate=(commaParts.length>=2&&facilityRe.test(rawFirstPart))
    ?rawFirstPart
    :parentheticalVenue;

  // When parentheses exist, always try the visible city before the qualifier.
  if(parenBase&&parenBase!==geoRawPlace&&!facilityRe.test(parenBase))pushGeo(parenBase);

  if(commaParts.length>=2){
    const first=commaParts[0],last=commaParts[commaParts.length-1];
    const stateCode=last.toUpperCase();
    const startsWithFacility=facilityRe.test(rawFirstPart);
    const cityBeforeRegion=commaParts.length>=3?commaParts[commaParts.length-2]:first;

    if(usStateCodes[stateCode]){
      const cityPart=startsWithFacility&&commaParts.length>=3?cityBeforeRegion:first;
      pushGeo(cityPart+", "+usStateCodes[stateCode]);
      pushGeo(cityPart);
    }else if(usStateNames.has(normalizeName(last))){
      const cityPart=startsWithFacility&&commaParts.length>=3?cityBeforeRegion:first;
      pushGeo(cityPart+", "+last);
      pushGeo(cityPart);
    }else if(startsWithFacility){
      // "complex, city, country/state" => city+region first, never complex as city.
      const cityPart=commaParts.length>=3?cityBeforeRegion:last;
      if(commaParts.length>=3)pushGeo(cityPart+", "+last);
      pushGeo(cityPart);
    }else{
      // Prefer a disambiguated city+region/country, then the bare city.
      pushGeo(first+", "+last);
      pushGeo(first);
    }
  }else if(commaParts.length===1){
    pushGeo(commaParts[0]);
  }

  // A qualifier can be a useful fallback only if no base city was available.
  if(!parenBase){
    for(const x of parentheticalParts){
      if(x&&!facilityRe.test(x)&&!/^(?:cancelled|canceled)$/i.test(x))pushGeo(x);
    }
  }
  if(!geoCandidates.length&&!facilityRe.test(geoRawPlace))pushGeo(geoRawPlace);

  const aliasBase=normalizeName(String(geoCandidates[0]||geoRawPlace||rawPlace).split(",")[0]);
  const geoAliasKey=String(t.country||"").toUpperCase()+"|"+aliasBase;
  const knownGeoAliases:Record<string,string>={
    "GER|halle":"Halle (Saale)",
    "ITA|fano":"Fano, Marche",
    "ITA|grado":"Grado, Friuli-Venezia Giulia",
    "ITA|lesa":"Lesa, Piedmont",
    "CHN|luan":"Lu'an, Anhui",
    "UNK|asuncion":"Asunción, Paraguay",
    "CGO|brazzaville":"Brazzaville, Republic of the Congo",
    "UNK|plovdiv":"Plovdiv, Bulgaria",
    "SUI|sion":"Sion, Switzerland",
    "AUS|brisbane":"Brisbane, Queensland"
  };
  const knownGeoAlias=knownGeoAliases[geoAliasKey];
  if(knownGeoAlias&&!geoCandidates.some(x=>normalizeName(x)===normalizeName(knownGeoAlias))){
    geoCandidates.unshift(knownGeoAlias);
  }

  const primaryCity=geoCandidates[0]||geoRawPlace||rawPlace;
  const syntheticPlace=/^ville\s+\d+$/i.test(primaryCity)||/^(?:rus|isr|ven)\s+tennis\s+center$/i.test(primaryCity);
  const curatedImageSources=[
    {re:/United Cup/i,url:"https://www.unitedcup.com/en/media/news/united-cup-2026-schedule-released"},
    {re:/Nitto ATP Finals/i,url:"https://www.nittoatpfinals.com/en/"},
    {re:/Next Gen ATP Finals/i,url:"https://www.nextgenatpfinals.com/en/"},
    {re:/Rolex Shanghai Masters/i,url:"https://en.rolexshanghaimasters.com/en/"}
  ];
  const curatedImageSource=curatedImageSources.find((x:any)=>x.re.test(String(t.name||"")))?.url||"";
  const source=String(curatedImageSource||(weakImage?t.source_url:(t.image_source_url||t.source_url))||"").trim();
  let canFetchOfficial=false;
  if(/^https?:\/\//i.test(source)&&!/github\.com|calendar-pdfs|what-is-the-2026-atp-tour-calendar|itftravelcoach|\.pdf(?:$|\?)/i.test(source)){
    try{
      const host=new URL(source).hostname.toLowerCase();
      const allowed=[
        "atptour.com","www.atptour.com","itftennis.com","www.itftennis.com",
        "ncaa.com","www.ncaa.com","ncaa.org","www.ncaa.org",
        "wearecollegetennis.com","www.wearecollegetennis.com",
        "ausopen.com","www.ausopen.com","rolandgarros.com","www.rolandgarros.com",
        "wimbledon.com","www.wimbledon.com","usopen.org","www.usopen.org",
        "wtatennis.com","www.wtatennis.com","sites.google.com",
        "brisbaneinternational.com.au","www.brisbaneinternational.com.au",
        "hkmenstennisopen.com","www.hkmenstennisopen.com",
        "adelaideinternational.com.au","www.adelaideinternational.com.au",
        "asbclassic.co.nz","www.asbclassic.co.nz",
        "openoccitanie.com","www.openoccitanie.com",
        "tenniseurope.org","www.tenniseurope.org",
        "daviscup.com","www.daviscup.com",
        "dallasopen.com","www.dallasopen.com","rioopen.com","www.rioopen.com",
        "abiertomexicanodetenis.com","www.abiertomexicanodetenis.com",
        "dubaidutyfreetennischampionships.com","www.dubaidutyfreetennischampionships.com",
        "barcelonaopenbancsabadell.com","www.barcelonaopenbancsabadell.com",
        "bmwopen.de","www.bmwopen.de","hamburgopenatp500.com","www.hamburgopenatp500.com",
        "terrawortmann-open.de","www.terrawortmann-open.de","japanopentennis.com","www.japanopentennis.com",
        "erstebank-open.com","www.erstebank-open.com","swissindoorsbasel.ch","www.swissindoorsbasel.ch",
        "mallorcachampionships.com","www.mallorcachampionships.com",
        "unitedcup.com","www.unitedcup.com",
        "nittoatpfinals.com","www.nittoatpfinals.com",
        "nextgenatpfinals.com","www.nextgenatpfinals.com",
        "rolexshanghaimasters.com","www.rolexshanghaimasters.com",
        "en.rolexshanghaimasters.com"
      ];
      canFetchOfficial=allowed.includes(host);
    }catch{}
  }

  if(canFetchOfficial){
    try{
      const r=await fetch(source,{
        headers:{"User-Agent":"CourtBoss/1.0 (+tournament-image-cache)","Accept":"text/html,application/xhtml+xml"},
        redirect:"follow",
        signal:timeoutSignal()
      });
      if(r.ok&&/text\/html|application\/xhtml\+xml/i.test(String(r.headers.get("content-type")||""))){
        const html=await r.text();
        const picks=[
          /<meta[^>]+property=["']og:image(?::secure_url)?["'][^>]+content=["']([^"']+)["']/i,
          /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image(?::secure_url)?["']/i,
          /<meta[^>]+name=["']twitter:image(?::src)?["'][^>]+content=["']([^"']+)["']/i,
          /<meta[^>]+content=["']([^"']+)["'][^>]+name=["']twitter:image(?::src)?["']/i
        ];
        let raw="";
        for(const re of picks){const m=html.match(re);if(m?.[1]){raw=String(m[1]).replace(/&amp;/g,"&").trim();break;}}
        try{if(raw)raw=new URL(raw,source).toString()}catch{}
        if(raw&&/^https?:\/\//i.test(raw)&&!/placeholder|default-avatar|favicon|sprite|logo/i.test(raw)&&!/\.(?:pdf|djvu)(?:\/|\.|$|\?)/i.test(raw)){
          t.image_url=raw;
          t.image_source_url=source;
          t.image_source_label="Visuel officiel du tournoi";
          await db.from("tournaments").update({
            image_url:raw,image_source_url:source,image_source_label:t.image_source_label
          }).eq("id",t.id);
        }
      }
    }catch{}
  }

  if(!t.image_url&&t.is_verified){
    try{
      const query=String(t.name)+" "+String(primaryCity||t.city||"")+" tennis";
      const qs=new URLSearchParams({
        action:"query",generator:"search",gsrsearch:query,gsrnamespace:"0",gsrlimit:"5",
        prop:"pageimages|info",piprop:"thumbnail|original",pithumbsize:"900",
        inprop:"url",format:"json",origin:"*"
      });
      const r=await fetch("https://en.wikipedia.org/w/api.php?"+qs.toString(),{
        headers:{"User-Agent":"CourtBoss/1.0 (+safe-tournament-image)"},
        signal:timeoutSignal()
      });
      if(r.ok){
        const j:any=await r.json();
        const pages=(Object.values(j?.query?.pages||{}) as any[]).sort((a:any,b:any)=>Number(a.index??999)-Number(b.index??999));
        const wanted=normalizeName(String(t.name||"")).replace(/\s+/g,"");
        const city=normalizeName(String(primaryCity||t.city||"")).replace(/\s+/g,"");
        const chosen=pages.find((x:any)=>{
          const title=normalizeName(String(x.title||"")).replace(/\s+/g,"");
          const nameHit=title===wanted||title.includes(wanted)||wanted.includes(title);
          const cityHit=city.length>=4&&title.includes(city);
          const tennisContext=/tennis|open|championship|masters|challenger|wimbledon|rolandgarros/i.test(String(x.title||""));
          return (nameHit||cityHit)&&tennisContext;
        });
        const raw=String(chosen?.original?.source||chosen?.thumbnail?.source||"").trim();
        if(raw&&/^https?:\/\//i.test(raw)&&!badImageRe.test(raw)&&!/logo|icon|flag|map/i.test(raw)&&!/\.(?:pdf|djvu)(?:\/|\.|$|\?)/i.test(raw)){
          t.image_url=raw;
          t.image_source_url=String(chosen?.fullurl||"https://en.wikipedia.org/");
          t.image_source_label="Wikipedia/Wikimedia · tournoi vérifié";
          await db.from("tournaments").update({
            image_url:raw,image_source_url:t.image_source_url,image_source_label:t.image_source_label
          }).eq("id",t.id);
        }
      }
    }catch{}
  }

  if(!t.image_url){
    try{
      const query=[String(t.name||""),String(primaryCity||t.city||""),"tennis"].filter(Boolean).join(" ");
      const qs=new URLSearchParams({
        action:"query",generator:"search",gsrsearch:query,gsrnamespace:"6",gsrlimit:"12",
        prop:"imageinfo",iiprop:"url",iiurlwidth:"1200",format:"json",origin:"*"
      });
      const r=await fetch("https://commons.wikimedia.org/w/api.php?"+qs.toString(),{
        headers:{"User-Agent":"CourtBoss/1.0 (+commons-tournament-photo)"},
        signal:timeoutSignal()
      });
      if(r.ok){
        const j:any=await r.json();
        const pages=(Object.values(j?.query?.pages||{}) as any[]).sort((a:any,b:any)=>Number(a.index??999)-Number(b.index??999));
        const nameNorm=normalizeName(String(t.name||""));
        const cityNorm=normalizeName(String(primaryCity||t.city||""));
        const bad=/logo|icon|flag|map|poster|trophy|draw|bracket|signature|autograph|portrait|headshot|press conference|player|new york times|golden state|newspaper|magazine|book|document|scan|djvu|table[ _-]?tennis|ping[ _-]?pong|pictogram|\.wav|\.ogg|\.mp3|audio|pronunciation/i;
        const tennis=/tennis|court|stadium|arena|open|championship|masters|tournament/i;
        const chosen=pages
          .map((x:any)=>{
            const title=String(x.title||"");
            const norm=normalizeName(title);
            const info=(x.imageinfo||[])[0]||{};
            const raw=String(info.thumburl||info.url||"").trim();
            let score=0;
            if(nameNorm&&norm.includes(nameNorm.replace(/\bpresented\b.*$/,"").trim()))score+=8;
            if(cityNorm&&norm.includes(cityNorm))score+=4;
            if(tennis.test(title))score+=3;
            if(/court|stadium|arena/i.test(title))score+=2;
            if(bad.test(title))score-=10;
            return {x,raw,title,score};
          })
          .filter((x:any)=>x.raw&&/^https?:\/\//i.test(x.raw)&&!badImageRe.test(x.raw)&&!bad.test(x.title)&&!/\.(?:pdf|djvu)(?:\/|\.|$|\?)/i.test(x.raw)&&x.score>-3)
          .sort((a:any,b:any)=>b.score-a.score)[0];
        if(chosen?.raw){
          t.image_url=chosen.raw;
          t.image_source_url="https://commons.wikimedia.org/wiki/"+encodeURIComponent(String(chosen.x.title||"").replace(/ /g,"_"));
          t.image_source_label="Wikimedia Commons · photo tournoi/lieu";
          await db.from("tournaments").update({
            image_url:t.image_url,image_source_url:t.image_source_url,image_source_label:t.image_source_label
          }).eq("id",t.id);
        }
      }
    }catch{}
  }

  if(!t.image_url&&venueCandidate){
    try{
      const qs=new URLSearchParams({
        action:"query",generator:"search",
        gsrsearch:`"${venueCandidate}" "${primaryCity}"`,
        gsrnamespace:"0",gsrlimit:"8",
        prop:"pageimages|info",piprop:"thumbnail|original",pithumbsize:"1400",
        inprop:"url",format:"json",origin:"*"
      });
      const r=await fetch("https://en.wikipedia.org/w/api.php?"+qs.toString(),{
        headers:{"User-Agent":"CourtBoss/1.0 (+venue-photo-fallback)"},
        signal:timeoutSignal()
      });
      if(r.ok){
        const jj:any=await r.json();
        const pages=(Object.values(jj?.query?.pages||{}) as any[]).sort((a:any,b:any)=>Number(a.index??999)-Number(b.index??999));
        const venueTokens=normalizeName(venueCandidate).split(" ").filter(x=>(x.length>=3||/\d/.test(x))&&!/^(arena|stadium|center|centre|club|sports|tennis|golf|coliseum|training|academy)$/.test(x));
        const cityToken=normalizeName(primaryCity).replace(/\s+/g,"");
        const chosen=pages
          .map((x:any)=>{
            const title=normalizeName(String(x.title||""));
            const titleCompact=title.replace(/\s+/g,"");
            const raw=String(x?.original?.source||x?.thumbnail?.source||"").trim();
            let score=0,venueHits=0;
            for(const tok of venueTokens){
              if(title.includes(tok)){score+=3;venueHits++}
            }
            if(cityToken&&titleCompact.includes(cityToken))score+=4;
            if(/arena|stadium|coliseum|tennis|sports|centre|center|club/i.test(String(x.title||"")))score+=2;
            if(/station|railway|train|airport|person|film|song|album|berry/i.test(String(x.title||"")))score-=10;
            return {x,raw,score,venueHits};
          })
          .filter((x:any)=>x.raw&&/^https?:\/\//i.test(x.raw)&&!badImageRe.test(x.raw)&&!/logo|icon|flag|map|coat.of.arms|djvu/i.test(x.raw)
            &&x.score>=4&&(venueTokens.length===0||x.venueHits>0))
          .sort((a:any,b:any)=>b.score-a.score)[0];
        if(chosen?.raw){
          t.image_url=chosen.raw;
          t.image_source_url=String(chosen.x?.fullurl||"https://en.wikipedia.org/");
          t.image_source_label="Wikipedia/Wikimedia · lieu du tournoi · "+venueCandidate+", "+primaryCity;
          await db.from("tournaments").update({
            image_url:t.image_url,image_source_url:t.image_source_url,image_source_label:t.image_source_label
          }).eq("id",t.id);
        }
      }
    }catch{}
  }

  if(!t.image_url&&t.city&&!syntheticPlace){
    try{
      const rawCity=String(t.city||"").trim();
      const nonGeoTitleRe=/\b(?:berry|actor|actress|singer|musician|film|album|song|surname|given name|disambiguation|river|national park|wrestler|company|corporation)\b/i;
      const pageLooksGeographic=(x:any,cityName:string)=>{
        const raw=String(x?.original?.source||x?.thumbnail?.source||"");
        const hasCoordinates=Array.isArray(x?.coordinates)&&x.coordinates.length>0;
        const titleText=normalizeName(String(x?.title||""));
        const cityText=normalizeName(cityName);
        const cityBase=normalizeName(String(cityName).split(",")[0]||cityName);
        const titleCompact=titleText.replace(/\s+/g,"");
        const cityCompact=cityText.replace(/\s+/g,"");
        const baseCompact=cityBase.replace(/\s+/g,"");
        const titleTokens=titleText.split(/\s+/).filter(Boolean);
        const baseTokens=cityBase.split(/\s+/).filter(Boolean);
        const titleMatch=titleText===cityText
          ||titleText===cityBase
          ||titleCompact===cityCompact
          ||titleCompact===baseCompact
          ||(cityBase&&titleText.startsWith(cityBase+" ")&&titleTokens.length<=baseTokens.length+3);
        const disambiguation=Boolean(x?.pageprops?.disambiguation);
        return !x?.missing&&!disambiguation&&hasCoordinates&&titleMatch&&!nonGeoTitleRe.test(titleText)
          &&raw&&!/logo|icon|flag|map|coat.of.arms|djvu/i.test(raw)
          &&!/\.(?:pdf|djvu)(?:\/|\.|$|\?)/i.test(raw);
      };
      let chosen:any=null;
      let chosenCity="";
      for(const cityName of geoCandidates.slice(0,6)){
        const exactQs=new URLSearchParams({
          action:"query",titles:cityName,redirects:"1",
          prop:"pageimages|info|coordinates|pageprops",piprop:"thumbnail|original",pithumbsize:"1200",
          inprop:"url",format:"json",origin:"*"
        });
        const exact=await fetch("https://en.wikipedia.org/w/api.php?"+exactQs.toString(),{
          headers:{"User-Agent":"CourtBoss/1.0 (+normalized-city-photo-fallback-v3)"},
          signal:timeoutSignal()
        });
        if(exact.ok){
          const jj:any=await exact.json();
          chosen=(Object.values(jj?.query?.pages||{}) as any[]).find((x:any)=>pageLooksGeographic(x,cityName))||null;
        }
        if(!chosen){
          const cityBase=String(cityName).split(",")[0].trim()||cityName;
          const searchQs=new URLSearchParams({
            action:"query",generator:"search",gsrsearch:`intitle:"${cityBase}"`,gsrnamespace:"0",gsrlimit:"10",
            prop:"pageimages|info|coordinates|pageprops",piprop:"thumbnail|original",pithumbsize:"1200",
            inprop:"url",format:"json",origin:"*"
          });
          const search=await fetch("https://en.wikipedia.org/w/api.php?"+searchQs.toString(),{
            headers:{"User-Agent":"CourtBoss/1.0 (+normalized-city-search-fallback-v3)"},
            signal:timeoutSignal()
          });
          if(search.ok){
            const jj:any=await search.json();
            const pages=(Object.values(jj?.query?.pages||{}) as any[]).sort((a:any,b:any)=>Number(a.index??999)-Number(b.index??999));
            chosen=pages.find((x:any)=>pageLooksGeographic(x,cityName))||null;
          }
        }
        if(chosen){chosenCity=cityName;break}
      }

      const raw=String(chosen?.original?.source||chosen?.thumbnail?.source||"").trim();
      if(raw&&/^https?:\/\//i.test(raw)&&!/\.(?:pdf|djvu)(?:\/|\.|$|\?)/i.test(raw)){
        t.image_url=raw;
        t.image_source_url=String(chosen?.fullurl||"https://en.wikipedia.org/");
        t.image_source_label="Photo de la ville · Wikipedia/Wikimedia · lieu normalisé: "+String(chosenCity||primaryCity||rawCity);
        await db.from("tournaments").update({
          image_url:raw,image_source_url:t.image_source_url,image_source_label:t.image_source_label
        }).eq("id",t.id);
      }
    }catch{}
  }
  if(!t.image_url&&(syntheticPlace||!geoCandidates.length)){
    try{
      const pool=await db.from("tournaments")
        .select("id,name,category,circuit,image_url,image_source_url,image_source_label")
        .eq("is_active",true)
        .eq("category",String(t.category||""))
        .neq("id",Number(t.id))
        .not("image_url","is",null)
        .limit(120);
      if(!pool.error){
        const strong=(pool.data??[]).filter((x:any)=>{
          const label=String(x.image_source_label||"");
          const url=String(x.image_url||"");
          return url
            &&!/Photo de la ville|Fallback circuit|Fallback compétition|Fallback catégorie|réutilisée/i.test(label)
            &&!badImageRe.test(url)
            &&!badImageRe.test(String(x.image_source_url||""));
        });
        if(strong.length){
          const ix=Math.abs(Number(t.id||0))%strong.length;
          const pick:any=strong[ix];
          t.image_url=String(pick.image_url||"");
          t.image_source_url=String(pick.image_source_url||"");
          t.image_source_label="Fallback catégorie · "+String(t.category||t.circuit||"Tour")+" · photo "+String(pick.name||"tournoi similaire");
          await db.from("tournaments").update({
            image_url:t.image_url,
            image_source_url:t.image_source_url,
            image_source_label:t.image_source_label
          }).eq("id",t.id);
        }
      }
    }catch{}
  }

  const syntheticBadFallback=syntheticPlace&&/Photo de la ville|Fallback circuit|Fallback compétition|Fallback catégorie/i.test(fallbackSourceLabel);
  if(!t.image_url&&fallbackImage&&!badCachedImage&&!syntheticBadFallback){
    t.image_url=fallbackImage;
    t.image_source_url=fallbackSourceUrl;
    t.image_source_label=fallbackSourceLabel;
  }
  return t;
}

function saveId(req:Request){const k=req.headers.get("x-save-key")??"";return /^[0-9a-f-]{36}$/i.test(k)?"browser:"+k:null}
async function getManagedPlayer(select="*"){
  const c=await db.from("career_state").select("managed_player_id").eq("id","demo").maybeSingle();
  if(c.error)return {data:null,error:c.error};
  if(!c.data?.managed_player_id)return {data:null,error:{message:"Managed player missing"}};
  return await db.from("players").select(select).eq("id",c.data.managed_player_id).maybeSingle();
}

async function recordFinanceTransactions(rows:any[]){
  const clean=(Array.isArray(rows)?rows:[])
    .filter((x:any)=>x&&Number(x.amount||0)!==0&&String(x.transaction_key||"").trim())
    .map((x:any)=>({
      transaction_key:String(x.transaction_key).slice(0,180),
      game_date:String(x.game_date||AGE_REFERENCE_DATE).slice(0,10),
      week:x.week==null?null:Number(x.week),
      category:String(x.category||"other").slice(0,60),
      amount:Number(x.amount||0),
      currency:String(x.currency||"EUR").slice(0,3).toUpperCase(),
      source_type:x.source_type?String(x.source_type).slice(0,60):null,
      source_id:x.source_id==null?null:Number(x.source_id),
      description:String(x.description||"Mouvement financier").slice(0,240),
      balance_after:x.balance_after==null?null:Number(x.balance_after),
      metadata:x.metadata&&typeof x.metadata==="object"?x.metadata:{}
    }));
  if(!clean.length)return {ok:true,inserted:0};
  const r=await db.from("finance_transactions").upsert(clean,{onConflict:"transaction_key",ignoreDuplicates:true});
  if(r.error){
    console.warn("Finance ledger",r.error.message);
    return {ok:false,error:r.error.message,inserted:0};
  }
  return {ok:true,inserted:clean.length};
}

async function captureManagedSaveSnapshot(){
  const career=await db.from("career_state").select("*").eq("id","demo").maybeSingle();
  if(career.error||!career.data)throw new Error(career.error?.message||"Career missing");
  const managedId=Number(career.data.managed_player_id||0);
  const nation=String(career.data.federation_nation||career.data.selected_federation_nation||career.data.country||"FRA");

  const [
    academy,finance,financeTransactions,facilities,staff,contracts,roster,members,memberProgress,youth,intakeHistory,
    training,trainingProgress,medical,scouting,scoutingReports,sponsors,board,player,attrs,development,ceilings,
    entries,doublesEntries,wildcards,agency,doublesCommitments,partnerHistory,partnerOffers,inbox,media,
    seasonPlans,relationships,playerSponsors,staffAssignments,staffExternalOffers,eventLog,shortlist,
    collegeState,collegeOffers,ncaaRegistry,federation,davisSquad,seasonHistory,
    managedInjuries,trainingLoad,partnerships,matchHistory,tournamentRuns,doublesRuns,doublesMatchHistory
  ]=await Promise.all([
    db.from("academies").select("*").eq("id","demo").maybeSingle(),
    db.from("finances").select("*").eq("id","demo").maybeSingle(),
    db.from("finance_transactions").select("*").order("game_date",{ascending:true}).order("id",{ascending:true}),
    db.from("facilities").select("*").order("id"),
    db.from("staff").select("*").order("id"),
    db.from("contracts").select("*").order("id"),
    db.from("academy_roster").select("*").order("id"),
    db.from("academy_members").select("*").order("id"),
    db.from("academy_member_progress").select("*").order("member_id"),
    db.from("academy_youth").select("*").order("id"),
    db.from("academy_intake_history").select("*").eq("academy_id","demo").order("id"),
    db.from("training_plan").select("*").order("day_index"),
    db.from("user_training_progress").select("*").order("attribute"),
    db.from("medical_plan").select("*").eq("id","demo").maybeSingle(),
    db.from("scouting_assignments").select("*").order("id"),
    db.from("scouting_reports").select("*").order("id"),
    db.from("sponsor_offers").select("*").order("id"),
    db.from("board_objectives").select("*").order("id"),
    managedId?db.from("players").select("*").eq("id",managedId).maybeSingle():Promise.resolve({data:null,error:null} as any),
    managedId?db.from("player_attributes").select("*").eq("player_id",managedId).maybeSingle():Promise.resolve({data:null,error:null} as any),
    managedId?db.from("player_development_profiles").select("*").eq("player_id",managedId).maybeSingle():Promise.resolve({data:null,error:null} as any),
    managedId?db.from("player_attribute_ceilings").select("*").eq("player_id",managedId).maybeSingle():Promise.resolve({data:null,error:null} as any),
    managedId?db.from("entries").select("*").eq("player_id",managedId):Promise.resolve({data:[],error:null} as any),
    managedId?db.from("managed_doubles_entries").select("*").eq("owner_id","demo").eq("player_id",managedId):Promise.resolve({data:[],error:null} as any),
    db.from("wildcard_requests").select("*").order("id"),
    managedId?db.from("player_agency_representation").select("*").eq("player_id",managedId):Promise.resolve({data:[],error:null} as any),
    managedId?db.from("player_doubles_commitments").select("*").eq("player_id",managedId):Promise.resolve({data:[],error:null} as any),
    managedId?db.from("player_doubles_partner_history").select("*").eq("player_id",managedId).order("id"):Promise.resolve({data:[],error:null} as any),
    managedId?db.from("doubles_partner_offers").select("*").or("from_player_id.eq."+managedId+",to_player_id.eq."+managedId).order("id"):Promise.resolve({data:[],error:null} as any),
    db.from("inbox_items").select("*").order("id"),
    db.from("media_events").select("*").order("id"),
    managedId?db.from("player_season_plans").select("*").eq("player_id",managedId).order("season"):Promise.resolve({data:[],error:null} as any),
    managedId?db.from("player_relationships").select("*").or("player_a_id.eq."+managedId+",player_b_id.eq."+managedId).order("id"):Promise.resolve({data:[],error:null} as any),
    managedId?db.from("player_sponsors").select("*").eq("player_id",managedId).order("id"):Promise.resolve({data:[],error:null} as any),
    managedId?db.from("player_staff_assignments").select("*").eq("player_id",managedId).order("id"):Promise.resolve({data:[],error:null} as any),
    db.from("user_staff_external_offers").select("*").order("id"),
    db.from("career_event_log").select("*").order("id"),
    db.from("shortlist").select("*").order("added_at"),
    db.from("college_career_state").select("*").eq("id","demo").maybeSingle(),
    db.from("college_offers").select("*").order("id"),
    managedId?db.from("ncaa_player_registry").select("*").eq("player_id",managedId).order("id"):Promise.resolve({data:[],error:null} as any),
    db.from("federation_state").select("*").eq("nation",nation).maybeSingle(),
    db.from("davis_squad").select("*").eq("nation",nation).order("id"),
    db.from("season_history").select("*").order("id"),
    managedId?db.from("injuries").select("*").eq("player_id",managedId).order("id"):Promise.resolve({data:[],error:null} as any),
    managedId?db.from("player_training_load_profiles").select("*").eq("player_id",managedId).order("as_of_date"):Promise.resolve({data:[],error:null} as any),
    managedId?db.from("doubles_partnerships").select("*").or("player_a_id.eq."+managedId+",player_b_id.eq."+managedId).order("id"):Promise.resolve({data:[],error:null} as any),
    db.from("match_history").select("*").eq("user_involved",true).order("id"),
    db.from("tournament_runs").select("*").order("id"),
    db.from("doubles_runs").select("*").order("id"),
    db.from("doubles_match_history").select("*").order("id")
  ]);

  const all=[academy,finance,financeTransactions,facilities,staff,contracts,roster,members,memberProgress,youth,intakeHistory,training,trainingProgress,medical,scouting,scoutingReports,sponsors,board,player,attrs,development,ceilings,entries,doublesEntries,wildcards,agency,doublesCommitments,partnerHistory,partnerOffers,inbox,media,seasonPlans,relationships,playerSponsors,staffAssignments,staffExternalOffers,eventLog,shortlist,collegeState,collegeOffers,ncaaRegistry,federation,davisSquad,seasonHistory,managedInjuries,trainingLoad,partnerships,matchHistory,tournamentRuns,doublesRuns,doublesMatchHistory];
  const err=all.find((x:any)=>x?.error)?.error;
  if(err)throw new Error(err.message||"Snapshot failed");

  const ownProfileIds=[...new Set((staff.data??[]).map((x:any)=>Number(x.profile_id)).filter(Boolean))];
  const tournamentRunIds=(tournamentRuns.data??[]).map((x:any)=>Number(x.id)).filter(Boolean);
  const [staffProfiles,staffTraining,staffPeerRelationships,tournamentDrawMatches]=await Promise.all([
    ownProfileIds.length?db.from("staff_profiles").select("*").in("id",ownProfileIds).order("id"):Promise.resolve({data:[],error:null} as any),
    db.from("staff_training_enrollments").select("*").eq("user_managed",true).order("id"),
    ownProfileIds.length?db.from("staff_peer_relationships").select("*").or("staff_a_id.in.("+ownProfileIds.join(",")+"),staff_b_id.in.("+ownProfileIds.join(",")+")"):Promise.resolve({data:[],error:null} as any),
    tournamentRunIds.length?db.from("tournament_draw_matches").select("*").in("run_id",tournamentRunIds).order("id"):Promise.resolve({data:[],error:null} as any)
  ]);
  const detailErr=staffProfiles.error||staffTraining.error||staffPeerRelationships.error||tournamentDrawMatches.error;
  if(detailErr)throw new Error(detailErr.message||"Career detail snapshot failed");

  const academyManagedPlayerIds=[...new Set([
    managedId,
    ...(roster.data??[]).map((x:any)=>Number(x.player_id||0))
  ].filter(Boolean))];
  const [
    managedPlayersAll,managedAttributesAll,managedDevelopmentAll,managedCeilingsAll,
    managedInjuriesAll,managedTrainingLoadAll,managedTrainingProgressAll,managedSeasonPlansAll,
    managedEntriesAll,managedDoublesEntriesAll,managedAgencyAll,managedDoublesCommitmentsAll,
    managedPartnerHistoryAll,managedPartnerOffersAll,managedPartnershipsAll,managedRelationshipsAll,
    managedSponsorsAll,managedStaffAssignmentsAll,managedNcaaRegistryAll,managedRankingPointsAll,managedDoublesRankingPointsAll
  ]=await Promise.all([
    academyManagedPlayerIds.length?db.from("players").select("*").in("id",academyManagedPlayerIds).order("id"):Promise.resolve({data:[],error:null} as any),
    academyManagedPlayerIds.length?db.from("player_attributes").select("*").in("player_id",academyManagedPlayerIds).order("player_id"):Promise.resolve({data:[],error:null} as any),
    academyManagedPlayerIds.length?db.from("player_development_profiles").select("*").in("player_id",academyManagedPlayerIds).order("player_id"):Promise.resolve({data:[],error:null} as any),
    academyManagedPlayerIds.length?db.from("player_attribute_ceilings").select("*").in("player_id",academyManagedPlayerIds).order("player_id"):Promise.resolve({data:[],error:null} as any),
    academyManagedPlayerIds.length?db.from("injuries").select("*").in("player_id",academyManagedPlayerIds).order("id"):Promise.resolve({data:[],error:null} as any),
    academyManagedPlayerIds.length?db.from("player_training_load_profiles").select("*").in("player_id",academyManagedPlayerIds).order("player_id").order("as_of_date"):Promise.resolve({data:[],error:null} as any),
    academyManagedPlayerIds.length?db.from("managed_player_training_progress").select("*").in("player_id",academyManagedPlayerIds).order("player_id").order("attribute"):Promise.resolve({data:[],error:null} as any),
    academyManagedPlayerIds.length?db.from("player_season_plans").select("*").in("player_id",academyManagedPlayerIds).order("player_id").order("season"):Promise.resolve({data:[],error:null} as any),
    academyManagedPlayerIds.length?db.from("entries").select("*").in("player_id",academyManagedPlayerIds).order("id"):Promise.resolve({data:[],error:null} as any),
    academyManagedPlayerIds.length?db.from("managed_doubles_entries").select("*").eq("owner_id","demo").in("player_id",academyManagedPlayerIds).order("id"):Promise.resolve({data:[],error:null} as any),
    academyManagedPlayerIds.length?db.from("player_agency_representation").select("*").in("player_id",academyManagedPlayerIds).order("player_id"):Promise.resolve({data:[],error:null} as any),
    academyManagedPlayerIds.length?db.from("player_doubles_commitments").select("*").in("player_id",academyManagedPlayerIds).order("player_id"):Promise.resolve({data:[],error:null} as any),
    academyManagedPlayerIds.length?db.from("player_doubles_partner_history").select("*").in("player_id",academyManagedPlayerIds).order("id"):Promise.resolve({data:[],error:null} as any),
    academyManagedPlayerIds.length?db.from("doubles_partner_offers").select("*").or("from_player_id.in.("+academyManagedPlayerIds.join(",")+"),to_player_id.in.("+academyManagedPlayerIds.join(",")+")").order("id"):Promise.resolve({data:[],error:null} as any),
    academyManagedPlayerIds.length?db.from("doubles_partnerships").select("*").or("player_a_id.in.("+academyManagedPlayerIds.join(",")+"),player_b_id.in.("+academyManagedPlayerIds.join(",")+")").order("id"):Promise.resolve({data:[],error:null} as any),
    academyManagedPlayerIds.length?db.from("player_relationships").select("*").or("player_a_id.in.("+academyManagedPlayerIds.join(",")+"),player_b_id.in.("+academyManagedPlayerIds.join(",")+")").order("id"):Promise.resolve({data:[],error:null} as any),
    academyManagedPlayerIds.length?db.from("player_sponsors").select("*").in("player_id",academyManagedPlayerIds).order("id"):Promise.resolve({data:[],error:null} as any),
    academyManagedPlayerIds.length?db.from("player_staff_assignments").select("*").in("player_id",academyManagedPlayerIds).order("id"):Promise.resolve({data:[],error:null} as any),
    academyManagedPlayerIds.length?db.from("ncaa_player_registry").select("*").in("player_id",academyManagedPlayerIds).order("id"):Promise.resolve({data:[],error:null} as any),
    academyManagedPlayerIds.length?db.from("user_ranking_points").select("*").eq("owner_id","demo").in("player_id",academyManagedPlayerIds).order("id"):Promise.resolve({data:[],error:null} as any),
    academyManagedPlayerIds.length?db.from("user_doubles_points").select("*").eq("owner_id","demo").in("player_id",academyManagedPlayerIds).order("id"):Promise.resolve({data:[],error:null} as any)
  ]);
  const multiPlayerErr=
    managedPlayersAll.error||managedAttributesAll.error||managedDevelopmentAll.error||managedCeilingsAll.error||
    managedInjuriesAll.error||managedTrainingLoadAll.error||managedTrainingProgressAll.error||managedSeasonPlansAll.error||
    managedEntriesAll.error||managedDoublesEntriesAll.error||managedAgencyAll.error||managedDoublesCommitmentsAll.error||
    managedPartnerHistoryAll.error||managedPartnerOffersAll.error||managedPartnershipsAll.error||managedRelationshipsAll.error||
    managedSponsorsAll.error||managedStaffAssignmentsAll.error||managedNcaaRegistryAll.error||managedRankingPointsAll.error||managedDoublesRankingPointsAll.error;
  if(multiPlayerErr)throw new Error(multiPlayerErr.message||"Multi-player snapshot failed");

  return {
    model:"CB-MANAGED-SAVE-v6",
    captured_at:new Date().toISOString(),
    career_date:career.data.career_date,
    week:career.data.week,
    managed_player_id:managedId||null,
    federation_nation:nation,
    career:career.data,
    academy:academy.data,
    finance:finance.data,
    finance_transactions:financeTransactions.data??[],
    facilities:facilities.data??[],
    staff:staff.data??[],
    staff_profiles:staffProfiles.data??[],
    staff_training:staffTraining.data??[],
    staff_assignments:staffAssignments.data??[],
    staff_external_offers:staffExternalOffers.data??[],
    staff_peer_relationships:staffPeerRelationships.data??[],
    contracts:contracts.data??[],
    academy_roster:roster.data??[],
    academy_members:members.data??[],
    academy_member_progress:memberProgress.data??[],
    academy_youth:youth.data??[],
    academy_intake_history:intakeHistory.data??[],
    training_plan:training.data??[],
    training_progress:trainingProgress.data??[],
    training_load:trainingLoad.data??[],
    medical_plan:medical.data,
    managed_injuries:managedInjuries.data??[],
    scouting_assignments:scouting.data??[],
    scouting_reports:scoutingReports.data??[],
    sponsor_offers:sponsors.data??[],
    board_objectives:board.data??[],
    managed_player:player.data,
    managed_attributes:attrs.data,
    managed_development:development.data,
    managed_ceilings:ceilings.data,
    managed_players:managedPlayersAll.data??[],
    managed_attributes_all:managedAttributesAll.data??[],
    managed_development_all:managedDevelopmentAll.data??[],
    managed_ceilings_all:managedCeilingsAll.data??[],
    managed_injuries_all:managedInjuriesAll.data??[],
    training_load_all:managedTrainingLoadAll.data??[],
    managed_training_progress_all:managedTrainingProgressAll.data??[],
    season_plans_all:managedSeasonPlansAll.data??[],
    managed_entries_all:managedEntriesAll.data??[],
    managed_doubles_entries_all:managedDoublesEntriesAll.data??[],
    managed_agency_all:managedAgencyAll.data??[],
    managed_doubles_commitments_all:managedDoublesCommitmentsAll.data??[],
    managed_partner_history_all:managedPartnerHistoryAll.data??[],
    managed_partner_offers_all:managedPartnerOffersAll.data??[],
    managed_partnerships_all:managedPartnershipsAll.data??[],
    managed_relationships_all:managedRelationshipsAll.data??[],
    managed_sponsors_all:managedSponsorsAll.data??[],
    managed_staff_assignments_all:managedStaffAssignmentsAll.data??[],
    managed_ncaa_registry_all:managedNcaaRegistryAll.data??[],
    managed_ranking_points_all:managedRankingPointsAll.data??[],
    managed_doubles_ranking_points_all:managedDoublesRankingPointsAll.data??[],
    season_plans:seasonPlans.data??[],
    relationships:relationships.data??[],
    player_sponsors:playerSponsors.data??[],
    entries:entries.data??[],
    managed_doubles_entries:doublesEntries.data??[],
    wildcard_requests:wildcards.data??[],
    agency:agency.data??[],
    doubles_commitments:doublesCommitments.data??[],
    doubles_partner_history:partnerHistory.data??[],
    partner_offers:partnerOffers.data??[],
    doubles_partnerships:partnerships.data??[],
    inbox:inbox.data??[],
    media_events:media.data??[],
    career_event_log:eventLog.data??[],
    shortlist:shortlist.data??[],
    college_state:collegeState.data,
    college_offers:collegeOffers.data??[],
    ncaa_registry:ncaaRegistry.data??[],
    federation_state:federation.data,
    davis_squad:davisSquad.data??[],
    season_history:seasonHistory.data??[],
    match_history:matchHistory.data??[],
    tournament_runs:tournamentRuns.data??[],
    tournament_draw_matches:tournamentDrawMatches.data??[],
    doubles_runs:doublesRuns.data??[],
    doubles_match_history:doublesMatchHistory.data??[]
  };
}

async function restoreManagedSaveSnapshot(snapshot:any){
  const storedModel=String(snapshot?.model||"");
  if(!snapshot||!["CB-MANAGED-SAVE-v1","CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6","CB-MANAGED-SAVE-v7"].includes(storedModel))throw new Error("Unsupported save snapshot");
  const liveCheckpoint=storedModel==="CB-MANAGED-SAVE-v7";
  const model=liveCheckpoint?"CB-MANAGED-SAVE-v6":storedModel;

  const upsertOne=async(table:string,row:any,onConflict?:string)=>{
    if(!row)return;
    const q=onConflict?db.from(table).upsert(row,{onConflict}):db.from(table).upsert(row);
    const r=await q;if(r.error)throw new Error(table+": "+r.error.message);
  };
  const upsertMany=async(table:string,rows:any[],onConflict?:string)=>{
    if(!Array.isArray(rows)||!rows.length)return;
    const q=onConflict?db.from(table).upsert(rows,{onConflict}):db.from(table).upsert(rows);
    const r=await q;if(r.error)throw new Error(table+": "+r.error.message);
  };
  const deleteAll=async(table:string,column="id")=>{
    const r=await db.from(table).delete().not(column,"is",null);
    if(r.error)throw new Error(table+" cleanup: "+r.error.message);
  };

  const managedId=Number(snapshot.managed_player_id||snapshot.career?.managed_player_id||0);
  const nation=String(snapshot.federation_nation||snapshot.career?.federation_nation||snapshot.career?.selected_federation_nation||snapshot.career?.country||"FRA");

  let currentManagedId=0;
  let currentNation=nation;
  let currentStaffProfileIds:number[]=[];
  let currentAcademyPlayerIds:number[]=[];
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model)){
    const currentCareer=await db.from("career_state")
      .select("managed_player_id,federation_nation,selected_federation_nation,country")
      .eq("id","demo").maybeSingle();
    if(currentCareer.error)throw new Error("current career cleanup: "+currentCareer.error.message);
    currentManagedId=Number(currentCareer.data?.managed_player_id||0);
    currentNation=String(
      currentCareer.data?.federation_nation
      ||currentCareer.data?.selected_federation_nation
      ||currentCareer.data?.country
      ||nation
    );
    const currentStaffProfiles=await db.from("staff").select("profile_id");
    if(currentStaffProfiles.error)throw new Error("staff profile cleanup: "+currentStaffProfiles.error.message);
    currentStaffProfileIds=[...new Set((currentStaffProfiles.data??[]).map((x:any)=>Number(x.profile_id)).filter(Boolean))];
    if(["CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model)){
      const currentAcademy=await db.from("academy_roster").select("player_id").not("player_id","is",null);
      if(currentAcademy.error)throw new Error("academy player cleanup: "+currentAcademy.error.message);
      currentAcademyPlayerIds=[...new Set((currentAcademy.data??[]).map((x:any)=>Number(x.player_id)).filter(Boolean))];
    }
  }
  const snapshotManagedPlayerIds=["CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model)
    ?[...new Set((snapshot.managed_players??[]).map((x:any)=>Number(x.id)).filter(Boolean))]
    :[];
  const managedCleanupIds=["CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model)
    ?[...new Set([currentManagedId,managedId,...currentAcademyPlayerIds,...snapshotManagedPlayerIds].filter(Boolean))]
    :[...new Set([currentManagedId,managedId].filter(Boolean))];
  const academyStateCleanupIds=["CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model)
    ?[...new Set([managedId,...snapshotManagedPlayerIds].filter(Boolean))]
    :[];
  const nationCleanup=[...new Set([currentNation,nation].filter(Boolean))];

  // A load is an exact rollback boundary for live coaching too. Any unsaved active
  // session is discarded; a V7 manual/quick checkpoint is reinserted below.
  const checkpointLiveIds=liveCheckpoint
    ?[...new Set((snapshot.live_match_sessions??[]).map((x:any)=>Number(x.id)).filter(Boolean))]
    :[];
  if(checkpointLiveIds.length){
    const savedLiveCleanup=await db.from("live_match_sessions").delete().in("id",checkpointLiveIds);
    if(savedLiveCleanup.error)throw new Error("live checkpoint cleanup: "+savedLiveCleanup.error.message);
  }
  for(const cleanupPlayerId of managedCleanupIds){
    const liveCleanup=await db.from("live_match_sessions")
      .delete().eq("managed_player_id",cleanupPlayerId).in("status",["active","finished"]);
    if(liveCleanup.error)throw new Error("live session cleanup: "+liveCleanup.error.message);
    if(snapshot.captured_at){
      const unsavedCompletedCleanup=await db.from("live_match_sessions")
        .delete().eq("managed_player_id",cleanupPlayerId).gt("started_at",String(snapshot.captured_at));
      if(unsavedCompletedCleanup.error)throw new Error("unsaved live session cleanup: "+unsavedCompletedCleanup.error.message);
    }
  }

  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model)){
    // Exact managed-world rewind. Global AI/world tournament state is intentionally not rewound.
    await deleteAll("inbox_items");
    await deleteAll("finance_transactions");
    await deleteAll("media_events");
    await deleteAll("career_event_log");
    await deleteAll("scouting_reports");
    await deleteAll("scouting_assignments");
    await deleteAll("sponsor_offers");
    await deleteAll("board_objectives");
    await deleteAll("contracts");
    await deleteAll("academy_member_progress","member_id");
    await deleteAll("academy_roster");
    await deleteAll("academy_members");
    await deleteAll("academy_intake_history");
    await deleteAll("academy_youth");
    await deleteAll("facilities");
    {
      const cleanTraining=await db.from("staff_training_enrollments").delete().eq("user_managed",true);
      if(cleanTraining.error)throw new Error("staff_training_enrollments cleanup: "+cleanTraining.error.message);
    }
    await deleteAll("staff");
    await deleteAll("training_plan","day_index");
    await deleteAll("user_training_progress","attribute");
    await deleteAll("shortlist");
    await deleteAll("college_offers");
    await db.from("college_career_state").delete().eq("id","demo");
    await deleteAll("season_history");
    await deleteAll("tournament_draw_matches");
    await deleteAll("tournament_runs");
    await deleteAll("doubles_match_history");
    await deleteAll("doubles_runs");
    await db.from("match_history").delete().eq("user_involved",true);
    await db.from("managed_doubles_entries").delete().eq("owner_id","demo");
    for(const cleanupPlayerId of managedCleanupIds){
      await db.from("entries").delete().eq("player_id",cleanupPlayerId);
      await db.from("player_agency_representation").delete().eq("player_id",cleanupPlayerId);
      await db.from("player_doubles_commitments").delete().eq("player_id",cleanupPlayerId);
      await db.from("player_doubles_partner_history").delete().eq("player_id",cleanupPlayerId);
      await db.from("doubles_partner_offers").delete().or("from_player_id.eq."+cleanupPlayerId+",to_player_id.eq."+cleanupPlayerId);
      await db.from("doubles_partnerships").delete().or("player_a_id.eq."+cleanupPlayerId+",player_b_id.eq."+cleanupPlayerId);
      await db.from("player_relationships").delete().or("player_a_id.eq."+cleanupPlayerId+",player_b_id.eq."+cleanupPlayerId);
      await db.from("player_sponsors").delete().eq("player_id",cleanupPlayerId);
      await db.from("player_staff_assignments").delete().eq("player_id",cleanupPlayerId);
      await db.from("player_season_plans").delete().eq("player_id",cleanupPlayerId);
      await db.from("player_training_load_profiles").delete().eq("player_id",cleanupPlayerId);
      await db.from("injuries").delete().eq("player_id",cleanupPlayerId);
      await db.from("ncaa_player_registry").delete().eq("player_id",cleanupPlayerId);
      await db.from("ranking_history").delete().eq("player_id",cleanupPlayerId).gt("snapshot_date",String(snapshot.career_date||AGE_REFERENCE_DATE));
      await db.from("doubles_ranking_history").delete().eq("player_id",cleanupPlayerId).gt("snapshot_date",String(snapshot.career_date||AGE_REFERENCE_DATE));
    }
    await db.from("wildcard_requests").delete().not("id","is",null);
    if(["CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model)){
      const pointsCleanup=await db.from("user_ranking_points").delete().eq("owner_id","demo");
      if(pointsCleanup.error)throw new Error("user_ranking_points cleanup: "+pointsCleanup.error.message);
    }
    if(model==="CB-MANAGED-SAVE-v6"){
      const doublesPointsCleanup=await db.from("user_doubles_points").delete().eq("owner_id","demo");
      if(doublesPointsCleanup.error)throw new Error("user_doubles_points cleanup: "+doublesPointsCleanup.error.message);
    }
    await db.from("user_staff_external_offers").delete().not("id","is",null);
    const peerIds=[...new Set([
      ...currentStaffProfileIds,
      ...(snapshot.staff??[]).map((x:any)=>Number(x.profile_id)).filter(Boolean)
    ])];
    if(peerIds.length){
      const peerDel=await db.from("staff_peer_relationships").delete().or("staff_a_id.in.("+peerIds.join(",")+"),staff_b_id.in.("+peerIds.join(",")+")");
      if(peerDel.error)throw new Error("staff peer cleanup: "+peerDel.error.message);
    }
    for(const cleanupNation of nationCleanup){
      const davisCleanup=await db.from("davis_squad").delete().eq("nation",cleanupNation);
      if(davisCleanup.error)throw new Error("davis_squad cleanup: "+davisCleanup.error.message);
    }
  }

  if(["CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model)&&academyStateCleanupIds.length){
    for(const playerId of academyStateCleanupIds){
      const injuryDel=await db.from("injuries").delete().eq("player_id",playerId);
      if(injuryDel.error)throw new Error("v3 injuries cleanup: "+injuryDel.error.message);
      const loadDel=await db.from("player_training_load_profiles").delete().eq("player_id",playerId);
      if(loadDel.error)throw new Error("v3 training load cleanup: "+loadDel.error.message);
      if(model==="CB-MANAGED-SAVE-v6"){
        const xpDel=await db.from("managed_player_training_progress").delete().eq("player_id",playerId);
        if(xpDel.error)throw new Error("v6 managed training XP cleanup: "+xpDel.error.message);
      }
      const seasonDel=await db.from("player_season_plans").delete().eq("player_id",playerId);
      if(seasonDel.error)throw new Error("v3 season plan cleanup: "+seasonDel.error.message);
    }
  }

  await upsertOne("career_state",snapshot.career,"id");
  await upsertOne("academies",snapshot.academy,"id");
  await upsertOne("finances",snapshot.finance,"id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("finance_transactions",snapshot.finance_transactions,"id");
  await upsertMany("facilities",snapshot.facilities,"id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("staff_profiles",snapshot.staff_profiles,"id");
  await upsertMany("staff",snapshot.staff,"id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("staff_training_enrollments",snapshot.staff_training,"id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("staff_peer_relationships",snapshot.staff_peer_relationships,"staff_a_id,staff_b_id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("player_staff_assignments",snapshot.staff_assignments,"id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("user_staff_external_offers",snapshot.staff_external_offers,"id");
  await upsertMany("contracts",snapshot.contracts,"id");
  await upsertMany("academy_youth",snapshot.academy_youth,"id");
  await upsertMany("academy_roster",snapshot.academy_roster,"id");
  await upsertMany("academy_members",snapshot.academy_members,"id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("academy_member_progress",snapshot.academy_member_progress,"member_id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("academy_intake_history",snapshot.academy_intake_history,"id");
  await upsertMany("training_plan",snapshot.training_plan,"day_index");
  await upsertMany("user_training_progress",snapshot.training_progress,"attribute");
  if(model==="CB-MANAGED-SAVE-v2")await upsertMany("player_training_load_profiles",snapshot.training_load,"player_id");
  await upsertOne("medical_plan",snapshot.medical_plan,"id");
  if(model==="CB-MANAGED-SAVE-v2")await upsertMany("injuries",snapshot.managed_injuries,"id");
  await upsertMany("scouting_assignments",snapshot.scouting_assignments,"id");
  await upsertMany("scouting_reports",snapshot.scouting_reports,"id");
  await upsertMany("sponsor_offers",snapshot.sponsor_offers,"id");
  await upsertMany("board_objectives",snapshot.board_objectives,"id");
  await upsertOne("players",snapshot.managed_player,"id");
  await upsertOne("player_attributes",snapshot.managed_attributes,"player_id");
  await upsertOne("player_development_profiles",snapshot.managed_development,"player_id");
  await upsertOne("player_attribute_ceilings",snapshot.managed_ceilings,"player_id");
  if(["CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model)){
    await upsertMany("players",snapshot.managed_players,"id");
    await upsertMany("player_attributes",snapshot.managed_attributes_all,"player_id");
    await upsertMany("player_development_profiles",snapshot.managed_development_all,"player_id");
    await upsertMany("player_attribute_ceilings",snapshot.managed_ceilings_all,"player_id");
    await upsertMany("injuries",snapshot.managed_injuries_all,"id");
    await upsertMany("player_training_load_profiles",snapshot.training_load_all,"player_id");
    if(model==="CB-MANAGED-SAVE-v6")await upsertMany("managed_player_training_progress",snapshot.managed_training_progress_all,"player_id,attribute");
    await upsertMany("player_season_plans",snapshot.season_plans_all,"player_id,season");
    if(["CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model)){
      await upsertMany("entries",snapshot.managed_entries_all,"id");
      await upsertMany("managed_doubles_entries",snapshot.managed_doubles_entries_all,"id");
      await upsertMany("player_agency_representation",snapshot.managed_agency_all,"player_id");
      await upsertMany("player_doubles_commitments",snapshot.managed_doubles_commitments_all,"player_id");
      await upsertMany("player_doubles_partner_history",snapshot.managed_partner_history_all,"id");
      await upsertMany("doubles_partner_offers",snapshot.managed_partner_offers_all,"id");
      await upsertMany("doubles_partnerships",snapshot.managed_partnerships_all,"id");
      await upsertMany("player_relationships",snapshot.managed_relationships_all,"id");
      await upsertMany("player_sponsors",snapshot.managed_sponsors_all,"id");
      await upsertMany("player_staff_assignments",snapshot.managed_staff_assignments_all,"id");
      await upsertMany("ncaa_player_registry",snapshot.managed_ncaa_registry_all,"id");
      if(["CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("user_ranking_points",snapshot.managed_ranking_points_all,"id");
      if(model==="CB-MANAGED-SAVE-v6")await upsertMany("user_doubles_points",snapshot.managed_doubles_ranking_points_all,"id");
    }
  }else if(["CB-MANAGED-SAVE-v2"].includes(model)){
    await upsertMany("player_season_plans",snapshot.season_plans,"player_id,season");
  }
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3"].includes(model))await upsertMany("player_relationships",snapshot.relationships,"id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3"].includes(model))await upsertMany("player_sponsors",snapshot.player_sponsors,"id");
  if(!["CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("entries",snapshot.entries,"id");
  if(!["CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("managed_doubles_entries",snapshot.managed_doubles_entries,"id");
  await upsertMany("wildcard_requests",snapshot.wildcard_requests,"id");
  if(!["CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("player_agency_representation",snapshot.agency,"player_id");
  if(!["CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("player_doubles_commitments",snapshot.doubles_commitments,"player_id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3"].includes(model))await upsertMany("player_doubles_partner_history",snapshot.doubles_partner_history,"id");
  if(!["CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("doubles_partner_offers",snapshot.partner_offers,"id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3"].includes(model))await upsertMany("doubles_partnerships",snapshot.doubles_partnerships,"id");
  await upsertMany("inbox_items",snapshot.inbox,"id");
  await upsertMany("media_events",snapshot.media_events,"id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("career_event_log",snapshot.career_event_log,"id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("shortlist",snapshot.shortlist,"id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertOne("college_career_state",snapshot.college_state,"id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("college_offers",snapshot.college_offers,"id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3"].includes(model))await upsertMany("ncaa_player_registry",snapshot.ncaa_registry,"id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertOne("federation_state",snapshot.federation_state,"nation");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("davis_squad",snapshot.davis_squad,"id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("season_history",snapshot.season_history,"id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("match_history",snapshot.match_history,"id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("tournament_runs",snapshot.tournament_runs,"id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("tournament_draw_matches",snapshot.tournament_draw_matches,"id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("doubles_runs",snapshot.doubles_runs,"id");
  if(["CB-MANAGED-SAVE-v2","CB-MANAGED-SAVE-v3","CB-MANAGED-SAVE-v4","CB-MANAGED-SAVE-v5","CB-MANAGED-SAVE-v6"].includes(model))await upsertMany("doubles_match_history",snapshot.doubles_match_history,"id");

  if(liveCheckpoint){
    await upsertMany("live_match_sessions",snapshot.live_match_sessions??[],"id");
    await upsertMany("live_match_events",snapshot.live_match_events??[],"id");
    await upsertMany("live_match_point_events",snapshot.live_match_point_events??[],"id");
  }

  return {ok:true,career_date:snapshot.career_date,week:snapshot.week,model:storedModel,snapshot_scope:liveCheckpoint?"managed_squad_live_checkpoint_exact_v7":model==="CB-MANAGED-SAVE-v6"?"managed_squad_ledgers_exact_v6":model==="CB-MANAGED-SAVE-v5"?"managed_squad_ledger_exact_v5":model==="CB-MANAGED-SAVE-v4"?"managed_squad_exact_v4":model==="CB-MANAGED-SAVE-v3"?"managed_academy_exact_v3":model==="CB-MANAGED-SAVE-v2"?"managed_world_exact_v2":"managed_world_v1",live_match_sessions:liveCheckpoint?(snapshot.live_match_sessions??[]):[]};
}

async function ensureCareerBaselineTemplate(){
  const existing=await db.from("game_career_templates").select("id,game_version").eq("id","default-2025-12-01").maybeSingle();
  if(existing.error)throw new Error(existing.error.message);
  if(existing.data)return {ok:true,created:false,id:existing.data.id};

  const career=await db.from("career_state").select("career_date,week").eq("id","demo").maybeSingle();
  if(career.error||!career.data)throw new Error(career.error?.message||"Career missing");
  if(String(career.data.career_date)!==AGE_REFERENCE_DATE||Number(career.data.week||1)!==1){
    return {ok:false,created:false,reason:"baseline_window_passed"};
  }

  const snapshot=await captureManagedSaveSnapshot();
  const localPayload={
    date:AGE_REFERENCE_DATE,week:1,
    training:["Service","Retour","Coup droit","Récupération","Déplacements","Match play","Repos"],
    entries:[],entryMeta:{},doublesEntries:[],doublesEntryMeta:{},shortlist:[],feed:[],
    scoutingBoost:0,partnerId:null,davisRoles:{},fantasy:[],
    tactics:{aggression:58,risk:52,net:28,returnPos:"Neutre"}
  };
  const ins=await db.from("game_career_templates").insert({
    id:"default-2025-12-01",managed_snapshot:snapshot,local_payload:localPayload,
    game_version:"2026.10-career-os-v6",updated_at:new Date().toISOString()
  });
  if(ins.error)throw new Error(ins.error.message);
  return {ok:true,created:true,id:"default-2025-12-01"};
}

function specialTeamEventMeta(t:any){
  const code=String(t?.entry_rule_code||""),category=String(t?.category||"");
  if(code==="UNITED_CUP_TEAM"||/United Cup/i.test(category))return {
    code:"united_cup",label:"Sélection nationale mixte",teams:18,
    format:"6 groupes de 3 · round robin · 8 équipes en quarts · demi-finales et finale",
    tie:"1 simple ATP · 1 simple WTA · 1 double mixte",
    selection:"Qualification du pays par classements ATP/WTA et sélection de l'équipe",
    playable:false
  };
  if(code==="LAVER_CUP_INVITE"||/Laver Cup/i.test(category))return {
    code:"laver_cup",label:"Invitation / sélection d'équipe",teams:2,
    format:"Team Europe vs Team World · 3 jours · premier à 13 points",
    tie:"4 matches vendredi · 4 samedi · jusqu'à 4 dimanche · au moins un double par jour",
    selection:"Six joueurs par équipe, via qualification et choix des capitaines",
    scoring:"1 point vendredi · 2 samedi · 3 dimanche",
    playable:false
  };
  if(code==="JUNIOR_DAVIS_SELECTION"||/Junior Davis Cup/i.test(category))return {
    code:"junior_davis",label:"Sélection nationale junior",teams:16,
    format:"4 groupes de 4 · round robin · jour de repos · phase à élimination directe",
    tie:"Rencontres par équipes nationales juniors",
    selection:"Qualification régionale puis sélection de la fédération",
    playable:false
  };
  return null;
}

async function managedTournamentPathwayBundle(tournamentId:number,requestedPlayerId?:number){
  const managed=await db.from("career_state").select("managed_player_id").eq("id","demo").maybeSingle();
  if(managed.error)throw managed.error;
  const primaryId=Number(managed.data?.managed_player_id||0);
  const playerId=Number(requestedPlayerId||primaryId||0);
  if(!playerId)throw new Error("Joueur managé introuvable");
  if(playerId!==primaryId){
    const roster=await db.from("academy_roster").select("id").eq("player_id",playerId).eq("status","active").maybeSingle();
    if(roster.error)throw roster.error;
    if(!roster.data)throw new Error("Ce joueur ne fait pas partie du groupe géré.");
  }
  const [base,se,pb]=await Promise.all([
    db.rpc("player_tournament_pathway_status",{p_player_id:playerId,p_target_tournament_id:tournamentId}),
    db.rpc("player_special_exempt_status",{p_player_id:playerId,p_target_tournament_id:tournamentId}),
    db.rpc("player_performance_bye_status",{p_player_id:playerId,p_target_tournament_id:tournamentId})
  ]);
  const err=base.error||se.error||pb.error;
  if(err)throw err;
  const basePath:any=base.data||{eligible:false,reason:"no_pathway"};
  const special:any=se.data||{eligible:false,reason:"no_special_exempt"};
  const performance:any=pb.data||{eligible:false,reason:"no_performance_bye"};
  const pathway=special?.eligible===true
    ?{eligible:true,mode:"special_exempt",label:"Special Exempt",details:special}
    :basePath;
  return {player_id:playerId,pathway,special_exempt:special,performance_bye:performance};
}

async function managedTournamentEntryRules(t:any,requestedPlayerId?:number){
  if(specialTeamEventMeta(t)||!["ATP","Challenger","ITF"].includes(String(t.circuit))||/Finals|Next Gen/i.test(String(t.category)))return null;
  const managed=await db.from("career_state").select("managed_player_id").eq("id","demo").maybeSingle();
  if(managed.error)throw managed.error;
  const primaryId=Number(managed.data?.managed_player_id||0);
  const playerId=Number(requestedPlayerId||primaryId||0);
  if(!playerId)return null;
  if(playerId!==primaryId){
    const roster=await db.from("academy_roster").select("id").eq("player_id",playerId).eq("status","active").maybeSingle();
    if(roster.error)throw roster.error;
    if(!roster.data)throw new Error("Ce joueur ne fait pas partie du groupe géré.");
  }
  const methods=["direct","qualifying","wildcard","alternate","protected","protected_qualifying"];
  const [checks,entry]=await Promise.all([
    Promise.all(methods.map(method=>db.rpc("player_event_eligibility",{p_player_id:playerId,p_tournament_id:t.id,p_entry_method:method}))),
    db.from("entries")
      .select("id,tournament_id,player_id,status,entry_method,entry_rank,requested_on,withdrawn_on,metadata,updated_at")
      .eq("tournament_id",t.id).eq("player_id",playerId).maybeSingle()
  ]);
  const error=checks.find(x=>x.error)?.error||entry.error;if(error)throw error;
  return {...Object.fromEntries(checks.map((result,index)=>[methods[index],result.data])),persisted_entry:entry.data??null,player_id:playerId};
}

async function projectedDoublesRaceRows(refDate:string,wanted:number,excludedIds:number[]=[],minRace=1,maxRace=2000){
  const date=String(refDate||AGE_REFERENCE_DATE).slice(0,10);
  const year=Number(date.slice(0,4));
  const fetchLimit=Math.min(2000,Math.max(160,Math.ceil(Math.max(1,wanted))*8));
  let rows:any[]=[];
  if(year<=2025){
    const race=await db.from("doubles_race_2025_full")
      .select("doubles_race_ranking,doubles_race_points,doubles_race_snapshot_date,source,player_one,player_two,player_one_id,player_two_id,name,country,is_team,finals_status")
      .gte("doubles_race_ranking",Math.max(1,minRace))
      .lte("doubles_race_ranking",Math.max(minRace,maxRace))
      .order("doubles_race_ranking",{ascending:true})
      .limit(fetchLimit);
    if(race.error)return {rows:[],error:race.error};
    rows=race.data??[];
  }else{
    const race=await db.rpc("doubles_race_for_date",{p_date:date});
    if(race.error)return {rows:[],error:race.error};
    rows=(race.data??[])
      .filter((x:any)=>Number(x.doubles_race_ranking||999999)>=minRace&&Number(x.doubles_race_ranking||999999)<=maxRace)
      .slice(0,fetchLimit);
  }

  const used=new Set<number>(excludedIds.map(Number).filter(Boolean));
  const selected:any[]=[];
  for(const row of rows){
    const aid=Number(row.player_one_id||0),bid=Number(row.player_two_id||0);
    if(!aid||!bid||aid===bid||used.has(aid)||used.has(bid))continue;
    selected.push(row);
    used.add(aid);used.add(bid);
    if(selected.length>=wanted)break;
  }
  return {rows:selected,error:null};
}

function doublesFieldBand(t:any){
  const category=String(t?.category||""),circuit=String(t?.circuit||"");
  if(/Finals/i.test(category))return {min:1,max:80,jitter:8,model:"finals_elite"};
  if(/Grand Chelem/i.test(category))return {min:1,max:280,jitter:28,model:"grand_slam"};
  if(/Masters 1000/i.test(category))return {min:1,max:240,jitter:24,model:"masters_1000"};
  if(/ATP 500/i.test(category))return {min:1,max:380,jitter:55,model:"atp_500"};
  if(/ATP 250/i.test(category))return {min:18,max:620,jitter:90,model:"atp_250"};
  if(circuit==="Challenger"){
    const level=Number((category.match(/(175|125|100|75|50)/)||[])[1]||75);
    if(level>=175)return {min:55,max:760,jitter:120,model:"challenger_175"};
    if(level>=125)return {min:90,max:950,jitter:150,model:"challenger_125"};
    if(level>=100)return {min:130,max:1150,jitter:190,model:"challenger_100"};
    if(level>=75)return {min:190,max:1500,jitter:240,model:"challenger_75"};
    return {min:280,max:1850,jitter:300,model:"challenger_50"};
  }
  if(circuit==="ITF"&&(/M25/i.test(category)||String(t?.entry_rule_code)==="ITF_M25"))return {min:480,max:2000,jitter:340,model:"itf_m25"};
  if(circuit==="ITF")return {min:760,max:2000,jitter:420,model:"itf_m15"};
  return {min:1,max:2000,jitter:160,model:"generic"};
}
async function projectedDoublesTournamentRows(t:any,refDate:string,wanted:number,excludedIds:number[]=[]){
  const band=doublesFieldBand(t);
  const pool=await projectedDoublesRaceRows(refDate,Math.max(96,wanted*6),excludedIds,band.min,band.max);
  if(pool.error)return {rows:[],error:pool.error,band};
  const tid=Number(t?.id||0);
  const ranked=pool.rows.slice().sort((a:any,c:any)=>{
    const jitter=(row:any)=>{
      const aid=Number(row.player_one_id||0),bid=Number(row.player_two_id||0),rr=Number(row.doubles_race_ranking||999999);
      const hash=Math.abs(((aid*73856093)^(bid*19349663)^(tid*83492791))>>>0)%1000;
      return rr+(hash/1000)*band.jitter;
    };
    return jitter(a)-jitter(c)||Number(a.doubles_race_ranking||999999)-Number(c.doubles_race_ranking||999999);
  });
  return {rows:ranked.slice(0,wanted),error:null,band};
}

const validEntryRank=(v:any)=>{
  const x=Number(v);
  return Number.isFinite(x)&&x>0&&x<99999?x:null;
};
const bestDoublesEntryRank=(p:any)=>{
  const singles=validEntryRank(p?.ranking),doubles=validEntryRank(p?.doubles_ranking);
  if(singles==null)return doubles;
  if(doubles==null)return singles;
  return Math.min(singles,doubles);
};
function doublesDrawComposition(t:any){
  const draw=tournamentDoublesDrawConfig(t).drawSize;
  const category=String(t?.category||"");
  const circuit=String(t?.circuit||"");
  if(/ATP Finals|Junior Double Finals/i.test(category))return {draw,direct:draw,advance:draw,onsite:0,wildcards:0,model:"finals"};
  if(/Grand Chelem/i.test(category))return {draw,direct:Math.max(0,draw-7),advance:Math.max(0,draw-7),onsite:0,wildcards:Math.min(7,draw),model:"grand_slam_2026"};
  if(circuit==="ITF"){
    const direct=Math.min(13,draw);
    if(/M25/i.test(category)||String(t?.entry_rule_code)==="ITF_M25"){
      return {draw,direct,advance:Math.min(7,direct),onsite:Math.max(0,direct-Math.min(7,direct)),wildcards:Math.max(0,draw-direct),model:"itf_m25"};
    }
    return {draw,direct,advance:0,onsite:direct,wildcards:Math.max(0,draw-direct),model:"itf_m15"};
  }
  if(circuit==="Challenger"){
    const advance=Math.min(10,draw),onsite=Math.min(4,Math.max(0,draw-advance));
    return {draw,direct:advance+onsite,advance,onsite,wildcards:Math.max(0,draw-advance-onsite),model:"challenger_2026"};
  }
  if(circuit==="ATP"&&/Masters 1000/i.test(category)){
    const wildcards=draw>=28?3:2;
    return {draw,direct:Math.max(0,draw-wildcards),advance:Math.max(0,draw-wildcards),onsite:0,wildcards,model:"masters_1000_2026"};
  }
  if(circuit==="ATP"&&/ATP 500/i.test(category)){
    const wildcards=Math.min(2,draw),qualifiers=draw>=4?1:0;
    const direct=Math.max(0,draw-wildcards-qualifiers);
    return {
      draw,direct,advance:direct,onsite:0,wildcards,qualifiers,
      qualifying_draw:qualifiers?4:0,
      qualifying_direct:qualifiers?3:0,
      qualifying_wildcards:qualifiers?1:0,
      model:"atp_500_2026"
    };
  }
  if(circuit==="ATP"&&/ATP 250/i.test(category)){
    const wildcards=Math.min(2,draw);
    return {draw,direct:Math.max(0,draw-wildcards),advance:Math.max(0,draw-wildcards),onsite:0,wildcards,qualifiers:0,qualifying_draw:0,model:"atp_250_2026"};
  }
  return {draw,direct:draw,advance:draw,onsite:0,wildcards:0,model:"generic"};
}
async function projectedDoublesAcceptanceCut(t:any,refDate:string,slots:number,mode:"best"|"doubles_only",excludedIds:number[]=[]){
  if(slots<=0)return {cut:null,field:0,slots,mode};
  const projected=await projectedDoublesTournamentRows(t,refDate,Math.max(96,slots*4),excludedIds);
  if(projected.error)throw projected.error;
  const ids=[...new Set(projected.rows.flatMap((x:any)=>[Number(x.player_one_id||0),Number(x.player_two_id||0)]).filter(Boolean))];
  const profiles=ids.length
    ?await db.from("players").select("id,ranking,doubles_ranking").in("id",ids)
    :{data:[],error:null};
  if(profiles.error)throw profiles.error;
  const byId=new Map((profiles.data??[]).map((p:any)=>[Number(p.id),p]));
  const scores:number[]=[];
  for(const row of projected.rows){
    const pa:any=byId.get(Number(row.player_one_id)),pb:any=byId.get(Number(row.player_two_id));
    if(!pa||!pb)continue;
    let ra:any,rb:any;
    const raceRank=Math.max(1,Number(row.doubles_race_ranking||999999));
    const raceEstimate=Math.max(1,Math.round(raceRank*2));
    if(mode==="doubles_only"){
      const aKnown=validEntryRank(pa.doubles_ranking),bKnown=validEntryRank(pb.doubles_ranking);
      ra=aKnown==null?raceEstimate:Math.min(aKnown,raceEstimate);
      rb=bKnown==null?raceEstimate:Math.min(bKnown,raceEstimate);
    }else{
      const aKnown=bestDoublesEntryRank(pa),bKnown=bestDoublesEntryRank(pb);
      ra=aKnown==null?raceEstimate:Math.min(aKnown,raceEstimate);
      rb=bKnown==null?raceEstimate:Math.min(bKnown,raceEstimate);
    }
    if(ra==null||rb==null)continue;
    scores.push(Number(ra)+Number(rb));
  }
  scores.sort((x,y)=>x-y);
  const idx=Math.min(slots,scores.length)-1;
  return {cut:idx>=0?scores[idx]:null,field:scores.length,slots,mode,band:projected.band};
}
async function managedDoublesEntryStatus(t:any,requestedPlayerId?:number){
  const career=await db.from("career_state").select("career_date,career_focus,managed_player_id").eq("id","demo").maybeSingle();
  if(career.error)throw career.error;
  const primaryId=Number(career.data?.managed_player_id||0);
  const playerId=Number(requestedPlayerId||primaryId||0);
  if(!playerId)throw new Error("Joueur managé introuvable");
  if(playerId!==primaryId){
    const roster=await db.from("academy_roster").select("id").eq("player_id",playerId).eq("status","active").maybeSingle();
    if(roster.error)throw roster.error;
    if(!roster.data)throw new Error("Ce joueur ne fait pas partie du groupe géré.");
  }
  const [managed,partnership]=await Promise.all([
    db.from("players").select("id,name,country,ranking,doubles_ranking,career_focus").eq("id",playerId).maybeSingle(),
    db.from("doubles_partnerships")
      .select("id,player_a_id,player_b_id,player_a:players!doubles_partnerships_player_a_id_fkey(id,name,country,ranking,doubles_ranking),player_b:players!doubles_partnerships_player_b_id_fkey(id,name,country,ranking,doubles_ranking)")
      .or("player_a_id.eq."+playerId+",player_b_id.eq."+playerId)
      .order("id",{ascending:false}).limit(1).maybeSingle()
  ]);
  const error=managed.error||partnership.error;
  if(error)throw error;
  if(!managed.data)throw new Error("Joueur introuvable");
  const now=String(career.data?.career_date||AGE_REFERENCE_DATE);
  const focus=String(managed.data?.career_focus||(playerId===primaryId?career.data?.career_focus:"mixed")||"mixed");
  const pair:any=partnership.data||null;
  const partner:any=pair
    ?(Number(pair.player_a_id)===playerId
      ?(Array.isArray(pair.player_b)?pair.player_b[0]:pair.player_b)
      :(Array.isArray(pair.player_a)?pair.player_a[0]:pair.player_a))
    :null;
  const composition=doublesDrawComposition(t);
  const specialTeamEvent=specialTeamEventMeta(t);
  if(specialTeamEvent)return {can_schedule:false,projected_acceptance:false,label:specialTeamEvent.label,phase:"selection",composition,team_event:specialTeamEvent};
  if(focus==="singles_only")return {can_schedule:false,projected_acceptance:false,label:"Simple exclusivement",phase:"career_focus",composition};
  if(!t?.doubles)return {can_schedule:false,projected_acceptance:false,label:"Pas de double",phase:"none",composition};
  if(["NCAA","Federation"].includes(String(t?.circuit)))return {can_schedule:false,projected_acceptance:false,label:"Par sélection",phase:"selection",composition};
  if(!partner)return {can_schedule:false,projected_acceptance:false,label:"Partenaire requis",phase:"partner",composition};

  const protectedDoubleRes=await db.rpc("player_entry_protection_status",{
    p_player_id:Number(managed.data?.id||0),p_event_type:"doubles",p_tournament_id:Number(t?.id||0)
  });
  if(protectedDoubleRes.error)throw protectedDoubleRes.error;
  const protectedDoubleInfo:any=protectedDoubleRes.data||null;

  const mine:any=managed.data;
  const mineBest=bestDoublesEntryRank(mine),partnerBest=bestDoublesEntryRank(partner);
  const mineDouble=validEntryRank(mine?.doubles_ranking),partnerDouble=validEntryRank(partner?.doubles_ranking);
  const protectedDoubleRank=protectedDoubleInfo?.available?validEntryRank(protectedDoubleInfo.protected_rank):null;
  const mineProtectedBest=protectedDoubleRank==null?mineBest:Math.min(validEntryRank(mine?.ranking)??protectedDoubleRank,protectedDoubleRank);
  const bestCombined=mineBest!=null&&partnerBest!=null?mineBest+partnerBest:null;
  const doublesCombined=mineDouble!=null&&partnerDouble!=null?mineDouble+partnerDouble:null;
  const protectedBestCombined=mineProtectedBest!=null&&partnerBest!=null?mineProtectedBest+partnerBest:null;
  const protectedDoublesCombined=protectedDoubleRank!=null&&partnerDouble!=null?protectedDoubleRank+partnerDouble:null;
  const advance=String(t?.doubles_entry_deadline||"");
  const onsite=String(t?.doubles_onsite_deadline||"");
  const ruleCode=String(t?.entry_rule_code||"");
  const category=String(t?.category||"");
  const method=String(t?.doubles_entry_method||(
    String(t?.circuit)==="ITF"&&(/M15/i.test(category)||ruleCode==="ITF_M15")?"onsite_only":
    String(t?.circuit)==="ITF"&&(/M25/i.test(category)||ruleCode==="ITF_M25")?"limited_advance_then_onsite":
    ["ATP","Challenger"].includes(String(t?.circuit))?"advance_then_onsite":""
  ));

  if(onsite&&now>onsite)return {
    can_schedule:false,projected_acceptance:false,label:"Double clos",phase:"closed",
    best_combined_rank:bestCombined,doubles_combined_rank:doublesCombined,composition,advance_deadline:advance||null,onsite_deadline:onsite||null,method
  };

  let phase="advance",slots=composition.advance,rankMode:"best"|"doubles_only"="best";
  if(method==="onsite_only"){
    phase="onsite";slots=composition.direct;
  }else if(method==="limited_advance_then_onsite"){
    if(advance&&now<=advance&&doublesCombined!=null){
      phase="advance";slots=Math.max(1,composition.advance);rankMode="doubles_only";
    }else{
      phase="onsite";slots=composition.direct;rankMode="best";
    }
  }else if(advance&&now>advance){
    phase="onsite";slots=composition.direct;
  }
  if(/Finals/i.test(category)){
    return {
      can_schedule:true,projected_acceptance:true,label:"Qualification par la Race",phase:"race",
      best_combined_rank:bestCombined,doubles_combined_rank:doublesCombined,composition,advance_deadline:advance||null,onsite_deadline:onsite||null,method
    };
  }

  const currentScore=rankMode==="doubles_only"?doublesCombined:bestCombined;
  const protectedScore=rankMode==="doubles_only"?protectedDoublesCombined:protectedBestCombined;
  if(currentScore==null&&protectedScore==null){
    return {
      can_schedule:phase==="onsite",projected_acceptance:false,
      label:phase==="onsite"?"Sign-in sur site · paire non classée":"Classement requis pour l’advance entry",
      phase,best_combined_rank:bestCombined,doubles_combined_rank:doublesCombined,composition,
      protected_ranking:protectedDoubleInfo,protected_combined_rank:protectedScore,
      advance_deadline:advance||null,onsite_deadline:onsite||null,method,ranking_mode:rankMode,projected_cut:null
    };
  }
  const cut=await projectedDoublesAcceptanceCut(t,now,slots,rankMode,[Number(mine?.id||0),Number(partner?.id||0)]);
  const acceptedCurrent=currentScore!=null&&(cut.cut==null||Number(currentScore)<=Number(cut.cut));
  const protectedCanHelp=!acceptedCurrent
    &&protectedDoubleInfo?.available===true
    &&protectedScore!=null
    &&currentScore!==protectedScore
    &&(cut.cut==null||Number(protectedScore)<=Number(cut.cut));
  const score=protectedCanHelp?protectedScore:currentScore;
  const accepted=protectedCanHelp||acceptedCurrent;

  const atp500Qualifying=String(t?.circuit)==="ATP"
    &&/ATP 500/i.test(category)
    &&Number(composition.qualifying_draw||0)===4
    &&Number(composition.qualifiers||0)===1
    &&phase==="advance";

  if(!accepted&&atp500Qualifying){
    const qDirectSlots=Math.max(0,Number(composition.qualifying_direct||3));
    const qCut=await projectedDoublesAcceptanceCut(
      t,now,Math.max(1,Number(composition.direct||0)+qDirectSlots),
      rankMode,[Number(mine?.id||0),Number(partner?.id||0)]
    );
    const qAcceptedCurrent=currentScore!=null&&(qCut.cut==null||Number(currentScore)<=Number(qCut.cut));
    const qProtectedCanHelp=!qAcceptedCurrent
      &&protectedDoubleInfo?.available===true
      &&protectedScore!=null
      &&currentScore!==protectedScore
      &&(qCut.cut==null||Number(protectedScore)<=Number(qCut.cut));
    const qAccepted=qAcceptedCurrent||qProtectedCanHelp;
    const qScore=qProtectedCanHelp?protectedScore:currentScore;
    const homePair=String(mine?.country||"")===String(t?.country||"")
      ||String(partner?.country||"")===String(t?.country||"");

    if(qAccepted){
      return {
        can_schedule:true,projected_acceptance:true,
        label:(qProtectedCanHelp?"Classement protégé double · ":"")+"Qualifications ATP 500 projetées · rang combiné "+qScore,
        phase:"qualifying",requires_qualifying:true,
        qualifying_entry_method:qProtectedCanHelp?"protected_qualifying":"qualifying",
        best_combined_rank:bestCombined,doubles_combined_rank:doublesCombined,score:qScore,
        protected_ranking:protectedDoubleInfo,protected_combined_rank:protectedScore,
        use_protected_ranking:qProtectedCanHelp,
        projected_cut:cut.cut,projected_field:cut.field,
        qualifying_cut:qCut.cut,qualifying_field:qCut.field,
        qualifying_wildcard_candidate:homePair,
        ranking_mode:rankMode,field_band:qCut.band,
        composition,advance_deadline:advance||null,onsite_deadline:onsite||null,method,
        partner:{id:partner.id,name:partner.name,country:partner.country,ranking:partner.ranking,doubles_ranking:partner.doubles_ranking}
      };
    }

    const qLabel=homePair
      ?"Hors cut qualifs directes · WC qualifs locale possible"
      :"Hors cut du tableau et des qualifications";
    return {
      can_schedule:true,projected_acceptance:false,label:qLabel,phase:"alternate",
      requires_qualifying:false,qualifying_wildcard_candidate:homePair,
      best_combined_rank:bestCombined,doubles_combined_rank:doublesCombined,score:qScore,
      protected_ranking:protectedDoubleInfo,protected_combined_rank:protectedScore,
      use_protected_ranking:false,
      projected_cut:cut.cut,projected_field:cut.field,
      qualifying_cut:qCut.cut,qualifying_field:qCut.field,
      ranking_mode:rankMode,field_band:qCut.band,
      composition,advance_deadline:advance||null,onsite_deadline:onsite||null,method,
      partner:{id:partner.id,name:partner.name,country:partner.country,ranking:partner.ranking,doubles_ranking:partner.doubles_ranking}
    };
  }

  const label=accepted
    ?(protectedCanHelp
      ?(phase==="advance"?"Classement protégé double · direct projeté "+score:"Classement protégé double · on-site projeté "+score)
      :(phase==="advance"?"Direct projeté · rang combiné "+score:"On-site projeté · rang combiné "+score))
    :(phase==="advance"?"Alternate projeté · rang combiné "+score:"Hors cut projeté · rang combiné "+score);
  return {
    can_schedule:true,projected_acceptance:accepted,label,phase,
    best_combined_rank:bestCombined,doubles_combined_rank:doublesCombined,score,
    protected_ranking:protectedDoubleInfo,protected_combined_rank:protectedScore,
    use_protected_ranking:protectedCanHelp,
    projected_cut:cut.cut,projected_field:cut.field,ranking_mode:rankMode,field_band:cut.band,
    composition,advance_deadline:advance||null,onsite_deadline:onsite||null,method,
    partner:{id:partner.id,name:partner.name,country:partner.country,ranking:partner.ranking,doubles_ranking:partner.doubles_ranking}
  };
}


async function publishActionableInbox(pDate?:string){
  const career=await db.from("career_state").select("career_date,managed_player_id").eq("id","demo").maybeSingle();
  if(career.error||!career.data)return {created:0,error:career.error?.message||"career_missing"};
  const date=String(pDate||career.data.career_date||AGE_REFERENCE_DATE);
  const managedId=Number(career.data.managed_player_id||0);

  const existing=await db.from("inbox_items")
    .select("related_entity_type,related_entity_id,action_type")
    .not("related_entity_type","is",null)
    .not("related_entity_id","is",null)
    .order("id",{ascending:false}).limit(1200);
  if(existing.error)return {created:0,error:existing.error.message};
  const seen=new Set((existing.data??[]).map((x:any)=>String(x.related_entity_type)+"|"+String(x.related_entity_id)+"|"+String(x.action_type||"")));
  const rows:any[]=[];
  const add=(row:any)=>{
    const key=String(row.related_entity_type)+"|"+String(row.related_entity_id)+"|"+String(row.action_type||"");
    if(seen.has(key))return;
    seen.add(key);rows.push(row);
  };
  const datePlus=(days:number)=>{
    const d=new Date(date+"T12:00:00Z");d.setUTCDate(d.getUTCDate()+days);return d.toISOString().slice(0,10);
  };

  const sponsors=await db.from("sponsor_offers").select("*").eq("status","available").order("weekly_value",{ascending:false});
  if(!sponsors.error){
    for(const x of sponsors.data??[])add({
      kind:"commercial",title:"Offre sponsor · "+String(x.brand||"Partenaire"),
      body:String(x.brand||"Un sponsor")+" propose "+Number(x.signing_bonus||0).toLocaleString("fr-FR")+" € de bonus puis "+Number(x.weekly_value||0).toLocaleString("fr-FR")+" €/sem. pendant "+Number(x.duration_weeks||0)+" semaines. "+String(x.requirement||""),
      action_route:"finance",game_date:date,priority:"high",is_read:false,
      action_type:"accept_sponsor",action_label:"Accepter",action_payload:{offer_id:Number(x.id)},
      secondary_action_type:"decline_sponsor",secondary_action_label:"Refuser",secondary_action_payload:{offer_id:Number(x.id)},
      decision_status:"pending",related_entity_type:"sponsor_offer",related_entity_id:Number(x.id),expires_at:datePlus(14)
    });
  }

  const staffOffers=await db.from("user_staff_external_offers").select("*").eq("status","pending").gte("deadline",date).order("deadline");
  if(!staffOffers.error&&(staffOffers.data??[]).length){
    const staffIds=[...new Set((staffOffers.data??[]).map((x:any)=>Number(x.staff_profile_id)).filter(Boolean))];
    const competitorIds=[...new Set((staffOffers.data??[]).map((x:any)=>Number(x.competitor_player_id)).filter(Boolean))];
    const [staffRows,competitors]=await Promise.all([
      staffIds.length?db.from("staff_profiles").select("id,name,primary_role").in("id",staffIds):Promise.resolve({data:[],error:null} as any),
      competitorIds.length?db.from("players").select("id,name,country,ranking").in("id",competitorIds):Promise.resolve({data:[],error:null} as any)
    ]);
    const sm=new Map((staffRows.data??[]).map((x:any)=>[Number(x.id),x]));
    const pm=new Map((competitors.data??[]).map((x:any)=>[Number(x.id),x]));
    for(const x of staffOffers.data??[]){
      const sp:any=sm.get(Number(x.staff_profile_id))||{},cp:any=pm.get(Number(x.competitor_player_id))||{};
      add({
        kind:"staff",title:"Offre extérieure · "+String(sp.name||"Membre du staff"),
        body:String(cp.name||"Un autre joueur")+" veut recruter "+String(sp.name||"un membre de ton staff")+" pour "+Number(x.offered_weekly||0).toLocaleString("fr-FR")+" €/sem. Tu peux aligner l'offre ou accepter son départ.",
        action_route:"staff",game_date:date,priority:"high",is_read:false,
        action_type:"match_staff_offer",action_label:"Aligner l’offre",action_payload:{offer_id:Number(x.id)},
        secondary_action_type:"release_staff_offer",secondary_action_label:"Laisser partir",secondary_action_payload:{offer_id:Number(x.id)},
        decision_status:"pending",related_entity_type:"staff_external_offer",related_entity_id:Number(x.id),expires_at:String(x.deadline||datePlus(7))
      });
    }
  }

  if(managedId){
    const partnerOffers=await db.from("doubles_partner_offers")
      .select("*,from_player:players!doubles_partner_offers_from_player_id_fkey(id,name,country,doubles_ranking)")
      .eq("to_player_id",managedId).eq("direction","incoming").eq("status","pending").gte("expires_at",date).order("expires_at");
    if(!partnerOffers.error){
      for(const x of partnerOffers.data??[]){
        const p:any=Array.isArray(x.from_player)?x.from_player[0]:x.from_player||{};
        add({
          kind:"double",title:"Proposition de double · "+String(p.name||"Joueur"),
          body:String(p.name||"Un joueur")+" te propose une association. Chimie "+Number(x.chemistry||0)+"/100, compatibilité "+Number(x.compatibility||0)+"/100, force de paire "+Number(x.pair_strength||0)+"/100.",
          action_route:"doubles",game_date:date,priority:"normal",is_read:false,
          action_type:"respond_partner_offer",action_label:"Accepter",action_payload:{offer_id:Number(x.id),decision:"accept"},
          secondary_action_type:"respond_partner_offer",secondary_action_label:"Refuser",secondary_action_payload:{offer_id:Number(x.id),decision:"decline"},
          decision_status:"pending",related_entity_type:"doubles_partner_offer",related_entity_id:Number(x.id),expires_at:String(x.expires_at||datePlus(7))
        });
      }
    }

    const injury=await db.from("injuries").select("*").eq("player_id",managedId).eq("status","Active").order("started_at",{ascending:false}).limit(1).maybeSingle();
    if(!injury.error&&injury.data){
      const x:any=injury.data;
      add({
        kind:"medical",title:"Décision médicale · "+String(x.injury_type||"Blessure"),
        body:"Retour estimé : "+String(x.expected_return||"date inconnue")+". Risque d'aggravation : "+Number(x.aggravation_risk||0)+"/100. Choisis le protocole.",
        action_route:"medical",game_date:date,priority:Number(x.aggravation_risk||0)>=60?"high":"normal",is_read:false,
        action_type:"medical_protocol",action_label:"Physio intensive",action_payload:{injury_id:Number(x.id),protocol:"Physio intensive"},
        secondary_action_type:"medical_protocol",secondary_action_label:"Récupération active",secondary_action_payload:{injury_id:Number(x.id),protocol:"Récupération active"},
        decision_status:"pending",related_entity_type:"injury",related_entity_id:Number(x.id),expires_at:datePlus(7)
      });
    }
  }

  if(rows.length){
    const ins=await db.from("inbox_items").insert(rows);
    if(ins.error)return {created:0,error:ins.error.message};
  }
  return {created:rows.length,commercial:rows.filter(x=>x.kind==="commercial").length,staff:rows.filter(x=>x.kind==="staff").length,doubles:rows.filter(x=>x.kind==="double").length,medical:rows.filter(x=>x.kind==="medical").length};
}

Deno.serve(async(req:Request)=>{
  if(req.method==="OPTIONS") return new Response(null,{status:204,headers:cors});
  const u=new URL(req.url), path=u.pathname;
  const accessKey=String(Deno.env.get("COURT_BOSS_ACCESS_KEY")||"").trim();
  const isHealth=path.endsWith("/api/health")||path.endsWith("/court-boss");
  // Read-only tournament images must be public: browser <img> requests cannot
  // attach the private Court Boss header. All other API routes stay protected.
  const isPublicTournamentImage=path.endsWith("/api/tournament-image")&&req.method==="GET";
  if(!isHealth&&!isPublicTournamentImage&&accessKey&&req.headers.get("x-court-boss-key")!==accessKey)return h({error:"Unauthorized"},401);
  if(isHealth) return h({ok:true,app:"court-boss-api",version:64,season_model:"priority-national-teams-united-cup-laver-pro-atp-finals-junior-ncaa-fatigue-sync-v26",tournament_model:"entry-calendar-prize-v9+public-image-cache-v11+venue-city-parser-v8+geo-aliases+media-type-guard+safe-category-fallback+doubles-seeding",development_model:"development-v3",match_model:"matchup-v4/point-v3+full-tournament-attrs",access_protected:Boolean(accessKey)});

  if((
    path.endsWith("/api/refresh-live-rankings")
    ||path.endsWith("/api/refresh-doubles-race")
    ||path.endsWith("/api/refresh-races")
  )&&req.method==="GET"){
    return h({
      ok:true,
      locked:true,
      baseline_snapshot:AGE_REFERENCE_DATE,
      reason:"Les classements de départ Court Boss sont figés au 01/12/2025. Les classements live postérieurs ne peuvent pas écraser la carrière; l'évolution après cette date est simulée par le moteur du jeu."
    });
  }

  if(path.endsWith("/api/bootstrap")&&req.method==="GET"){
    const sid=saveId(req);
    const currentCareer=await db.from("career_state").select("*").eq("id","demo").maybeSingle();
    if(currentCareer.error)return h({error:currentCareer.error.message},500);
    try{await ensureCareerBaselineTemplate()}catch(e){console.warn("Career baseline template",String((e as any)?.message||e))}
    if(currentCareer.data){
      const inboxSync=await db.rpc("career_sync_actionable_inbox",{
        p_date:String(currentCareer.data.career_date||AGE_REFERENCE_DATE),
        p_week:Number(currentCareer.data.week||1)
      });
      if(inboxSync.error)console.warn("Career inbox bootstrap sync",inboxSync.error.message);
      const operationalSync=await db.rpc("career_sync_operational_alerts",{
        p_date:String(currentCareer.data.career_date||AGE_REFERENCE_DATE),
        p_week:Number(currentCareer.data.week||1)
      });
      if(operationalSync.error)console.warn("Career operational inbox bootstrap sync",operationalSync.error.message);
    }
    const [career,academy,staff,facilities,finance,board,inbox,scouting,scoutingReports,youth,fed,news,matches,top,events,injuries,davis,training,medicalPlan,save,managedEntries,managedDoublesEntries] = await Promise.all([
      Promise.resolve(currentCareer),
      db.from("academies").select("*").eq("id","demo").maybeSingle(),
      db.from("staff").select("*,profile:staff_profiles(*)").order("id"),
      db.from("facilities").select("*").order("id"),
      db.from("finances").select("*").eq("id","demo").maybeSingle(),
      db.from("board_objectives").select("*").order("priority",{ascending:true}),
      db.from("inbox_items").select("*").order("created_at",{ascending:false}).limit(20),
      db.from("scouting_assignments").select("*,staff:staff_profiles!scouting_assignments_staff_profile_id_fkey(id,name,primary_role,nationality,scouting_rating,reputation,regions,workload,burnout,energy,operational_status,rest_until)").order("id"),
      db.from("scouting_reports").select("*,player:players!scouting_reports_player_id_fkey(id,name,country,ranking,game_world_rank,junior_ranking,age,birth_date,style,photo_url,ncaa_current,career_status)").order("report_date",{ascending:false}).order("confidence",{ascending:false}).limit(60),
      db.from("academy_youth").select("*").order("potential",{ascending:false}),
      db.from("federation_state").select("*").eq("nation","FRA").maybeSingle(),
      db.from("news_items").select("*").order("created_at",{ascending:false}).limit(12),
      db.from("match_history").select("*").eq("user_involved",true).order("match_date",{ascending:false}).limit(10),
      db.from("players").select("id,name,country,ranking,points,doubles_ranking,itf_ranking,age,current_ability,potential,form,fitness,morale,fatigue,style,is_real").eq("ranking_current",true).lte("ranking",30).order("ranking"),
      db.from("tournaments").select("*").eq("is_active",true).gte("start_date",currentCareer.data?.career_date||AGE_REFERENCE_DATE).order("start_date").limit(40),
      db.from("injuries").select("*,players(id,name,country,ranking)").order("started_at",{ascending:false}).limit(30),
      db.from("davis_squad").select("id,nation,role,players(id,name,country,ranking,points,doubles_ranking,form,fitness,morale,fatigue,style)").eq("nation","FRA").order("id"),
      db.from("training_plan").select("*").order("day_index"),
      db.from("medical_plan").select("*").eq("id","demo").maybeSingle(),
      sid?db.from("game_saves").select("payload").eq("id",sid).maybeSingle():Promise.resolve({data:null,error:null}),
      currentCareer.data?.managed_player_id
        ?db.from("entries")
          .select("id,tournament_id,player_id,status,entry_method,entry_rank,requested_on,withdrawn_on,metadata,updated_at,tournaments(id,name,country,circuit,category,start_date,end_date,qualifying_start_date,qualifying_end_date,main_draw_start_date,qualifying_entry_deadline,main_entry_deadline,singles_entry_deadline,late_entry_deadline)")
          .eq("player_id",currentCareer.data.managed_player_id).eq("status","entered")
          .order("requested_on",{ascending:true})
        :Promise.resolve({data:[],error:null}),
      currentCareer.data?.managed_player_id
        ?db.from("managed_doubles_entries")
          .select("id,owner_id,tournament_id,player_id,partner_id,status,entry_method,entry_phase,combined_rank,protected_combined_rank,projected_cut,requested_on,withdrawn_on,metadata,updated_at,partner:players!managed_doubles_entries_partner_id_fkey(id,name,country,ranking,doubles_ranking),tournaments(id,name,country,circuit,category,start_date,end_date,doubles_entry_deadline,doubles_onsite_deadline,qualifying_start_date,main_draw_start_date)")
          .eq("owner_id","demo").eq("player_id",currentCareer.data.managed_player_id).eq("status","entered")
          .order("requested_on",{ascending:true})
        :Promise.resolve({data:[],error:null})
    ]);
    const results=[career,academy,staff,facilities,finance,board,inbox,scouting,scoutingReports,youth,fed,news,matches,top,events,injuries,davis,training,medicalPlan,save,managedEntries,managedDoublesEntries];
    const err=results.find((x:any)=>x?.error)?.error;
    if(err) return h({error:err.message},500);
    return h({
      career:career.data,academy:academy.data,staff:staff.data??[],facilities:facilities.data??[],
      finance:finance.data,board:board.data??[],inbox:inbox.data??[],scouting:scouting.data??[],
      scoutingReports:scoutingReports.data??[],
      youth:youth.data??[],federation:fed.data,news:news.data??[],matches:matches.data??[],
      topPlayers:top.data??[],
      upcoming:(events.data??[])
        .filter((x:any)=>String(x.start_date)>=String(career.data?.career_date||AGE_REFERENCE_DATE))
        .filter((x:any)=>{
          const focus=String(career.data?.career_focus||"mixed");
          if(focus==="doubles_only")return Boolean(x.doubles);
          if(focus==="singles_only")return Boolean(x.singles);
          return true;
        })
        .slice(0,40),
      injuries:injuries.data??[],
      managedInjury:(injuries.data??[]).find((x:any)=>Number(x.player_id)===Number(career.data?.managed_player_id)&&x.status==="Active")??null,
      medicalPlan:medicalPlan.data??null,
      davisSquad:davis.data??[],training:training.data??[],save:save.data?.payload??null,
      entries:managedEntries.data??[],
      doublesEntries:managedDoublesEntries.data??[]
    });
  }

  if(path.endsWith("/api/rankings")&&req.method==="GET"){
    const kind=u.searchParams.get("kind")??"singles";
    const offset=n(u.searchParams.get("offset"),0,0,50000), limit=n(u.searchParams.get("limit"),100,1,200);
    const q=(u.searchParams.get("q")??"").trim().slice(0,80);
    const country=(u.searchParams.get("country")??"").trim().toUpperCase().slice(0,3);
    const nextGenU=n(u.searchParams.get("u"),21,18,21);
    const career=await db.from("career_state").select("career_date,managed_player_id").eq("id","demo").maybeSingle();
    const gameDate=String(career.data?.career_date||AGE_REFERENCE_DATE);


    if(kind==="doubles_race"){
      let race=db.rpc("doubles_race_for_date",{p_date:gameDate},{count:"exact"});
      if(q)race=race.ilike("name",`%${q}%`);
      if(country)race=race.eq("country",country);
      race=race.order("doubles_race_ranking",{ascending:true}).range(offset,offset+limit-1);
      const {data,error,count}=await race;
      if(error)return h({error:error.message},500);
      const rows=(data??[]).map((x:any)=>({...x,id:x.player_one_id??x.player_two_id??null}));
      return h({
        kind,offset,limit,count:count??0,rows,rankingDate:gameDate,
        finalsName:"Nitto ATP Finals · Double",qualificationPlaces:8,raceType:"team",
        officialPublishedThrough:Number(gameDate.slice(0,4))<=2025?10:null,
        approximateAfter:Number(gameDate.slice(0,4))<=2025?10:null,
        source:Number(gameDate.slice(0,4))<=2025
          ?"ATP doubles team race · published 2025 field + Court Boss estimated continuation"
          :"Court Boss simulated ATP doubles race"
      });
    }

    if(kind==="junior_race"){
      let race=db.rpc("junior_race_for_date",{p_date:gameDate},{count:"exact"});
      if(q)race=race.ilike("name_norm",`%${normalizeName(q)}%`);
      if(country)race=race.eq("country",country);
      race=race.order("junior_race_ranking",{ascending:true}).range(offset,offset+limit-1);
      const {data,error,count}=await race;
      if(error)return h({error:error.message},500);
      const rows=(data??[]).map((p:any)=>({
        ...p,
        age:ageAt(p.birth_date,AGE_REFERENCE_DATE,p.age,p.age_snapshot_date)
      }));
      return h({
        kind,offset,limit,count:count??0,rows,rankingDate:gameDate,
        finalsName:"ITF World Tennis Tour Junior Finals",qualificationPlaces:8,
        raceType:"player",qualificationWindow:"12 derniers mois",finalsPoints:1000,
        officialPublishedThrough:Number(gameDate.slice(0,4))<=2025?9:null,
        approximateAfter:Number(gameDate.slice(0,4))<=2025?9:null,
        source:Number(gameDate.slice(0,4))<=2025
          ?"ITF 2025 Junior Finals qualification field + Court Boss estimated continuation"
          :"Court Boss simulated Junior Finals race"
      });
    }

    if(kind==="junior_doubles_race"){
      let race=db.rpc("junior_doubles_race_for_date",{p_date:gameDate},{count:"exact"});
      if(q)race=race.ilike("name",`%${q}%`);
      if(country)race=race.eq("country",country);
      race=race.order("junior_doubles_race_ranking",{ascending:true}).range(offset,offset+limit-1);
      const {data,error,count}=await race;
      if(error)return h({error:error.message},500);
      const rows=(data??[]).map((x:any)=>({...x,id:x.player_one_id??x.player_two_id??null}));
      return h({
        kind,offset,limit,count:count??0,rows,rankingDate:gameDate,
        finalsName:"Court Boss Junior Doubles Finals",qualificationPlaces:8,
        raceType:"team",simulated:true,approximateAfter:0,
        source:"Court Boss · course de qualification Junior Double estimée/simulée"
      });
    }

    if(kind==="ncaa"){
      const playerSelect="id,name,country,ranking,ranking_current,ranking_source,source_ranking,points,doubles_ranking,age,age_source,age_snapshot_date,birth_date,current_ability,potential,form,fitness,morale,fatigue,style,data_source,photo_url,ncaa_current,ncaa_team_id,ncaa_rank,ncaa_school,ncaa_division,ncaa_status,ncaa_last_school,ncaa_verified,ncaa_utr_rating,ncaa_utr_verified,ncaa_utr_source,ncaa_class_year,ranking_snapshot_date";
      const rankingNcaaSeasonAt=(iso:any)=>{
        const s=String(iso||AGE_REFERENCE_DATE),y=Number(s.slice(0,4))||2025,m=Number(s.slice(5,7))||1;
        const start=m>=8?y:y-1;
        return String(start)+"-"+String((start+1)%100).padStart(2,"0");
      };
      const ncaaSeason=rankingNcaaSeasonAt(gameDate);
      const [officialReg,currentReg,currentPlayers,allAmericanReg,registryPool0,registryPool1,registryPool2,registryPool3,collegeTeams,schoolAliases]=await Promise.all([
        db.from("ncaa_player_registry")
          .select("id,ita_rank,ita_rank_official,projected_rank,school,division,season,status,snapshot_date,source_url,source_label,players!inner("+playerSelect+")")
          .eq("season",ncaaSeason)
          .lte("snapshot_date",gameDate)
          .not("ita_rank_official","is",null)
          .order("ita_rank_official",{ascending:true})
          .limit(125),
        db.from("ncaa_player_registry")
          .select("id,ita_rank,ita_rank_official,projected_rank,school,division,season,status,snapshot_date,source_url,source_label,players!inner("+playerSelect+")")
          .eq("season",ncaaSeason)
          .lte("snapshot_date",gameDate)
          // Depth is loaded separately. Official ITA rows have their own pool above,
          // so a future snapshot can never evict ranks 1-125 from the UI.
          .order("snapshot_date",{ascending:false})
          .order("ita_rank",{ascending:true,nullsFirst:false}).limit(1000),
        db.from("players").select(playerSelect).eq("ncaa_current",true)
          .lte("ncaa_snapshot_date",gameDate)
          .or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*").limit(1500),
        db.from("ncaa_player_registry")
          .select("id,ita_rank,ita_rank_official,projected_rank,school,division,season,status,snapshot_date,source_url,source_label,players!inner("+playerSelect+")")
          .eq("season","2025-26").eq("status","ITA All-American 2025-26").lte("snapshot_date",gameDate).limit(500),
        db.from("ncaa_player_registry")
          .select("id,ita_rank,ita_rank_official,projected_rank,school,division,season,status,snapshot_date,source_url,source_label,players!inner("+playerSelect+")")
          .lte("snapshot_date",gameDate).order("snapshot_date",{ascending:false}).order("id",{ascending:false}).range(0,999),
        db.from("ncaa_player_registry")
          .select("id,ita_rank,ita_rank_official,projected_rank,school,division,season,status,snapshot_date,source_url,source_label,players!inner("+playerSelect+")")
          .lte("snapshot_date",gameDate).order("snapshot_date",{ascending:false}).order("id",{ascending:false}).range(1000,1999),
        db.from("ncaa_player_registry")
          .select("id,ita_rank,ita_rank_official,projected_rank,school,division,season,status,snapshot_date,source_url,source_label,players!inner("+playerSelect+")")
          .lte("snapshot_date",gameDate).order("snapshot_date",{ascending:false}).order("id",{ascending:false}).range(2000,2999),
        db.from("ncaa_player_registry")
          .select("id,ita_rank,ita_rank_official,projected_rank,school,division,season,status,snapshot_date,source_url,source_label,players!inner("+playerSelect+")")
          .lte("snapshot_date",gameDate).order("snapshot_date",{ascending:false}).order("id",{ascending:false}).range(3000,3999),
        db.from("college_teams").select("id,name").limit(500),
        db.from("ncaa_school_team_aliases").select("school_name,team_id,is_active").eq("is_active",true).limit(1000)
      ]);
      const e=officialReg.error||currentReg.error||currentPlayers.error||allAmericanReg.error||registryPool0.error||registryPool1.error||registryPool2.error||registryPool3.error||collegeTeams.error||schoolAliases.error;
      if(e)return h({error:e.message},500);

      const ncaaSchoolKey=(v:any)=>String(v||"").trim().toLowerCase().replace(/[^a-z0-9]+/g,"");
      const teamNameById=new Map<number,string>((collegeTeams.data??[]).map((x:any)=>[Number(x.id),String(x.name||"")]));
      const teamIdBySchoolKey=new Map<string,number>();
      for(const x of collegeTeams.data??[]){
        const k=ncaaSchoolKey((x as any).name);
        if(k)teamIdBySchoolKey.set(k,Number((x as any).id));
      }
      for(const x of schoolAliases.data??[]){
        const k=ncaaSchoolKey((x as any).school_name);
        if(k)teamIdBySchoolKey.set(k,Number((x as any).team_id));
      }
      const canonicalNcaaSchool=(p:any,raw:any)=>{
        const direct=teamNameById.get(Number(p?.ncaa_team_id||0));
        if(direct)return direct;
        const id=teamIdBySchoolKey.get(ncaaSchoolKey(raw));
        return (id?teamNameById.get(id):null)||raw||p?.ncaa_school||p?.ncaa_last_school||null;
      };

      const byId=new Map<number,any>();
      const put=(p:any,meta:any,priority:number)=>{
        if(!p?.id)return;
        const id=Number(p.id);
        const old=byId.get(id);
        if(old&&Number(old.__priority??99)<=priority)return;
        const metaHasRank=!!meta&&Object.prototype.hasOwnProperty.call(meta,"ita_rank");
        const ncaaSource=String(meta?.source_label||meta?.source_url||p.ncaa_source||"");
        const rawRegistryRank=metaHasRank&&meta?.ita_rank!=null?Number(meta.ita_rank):null;
        const physicalOfficial=meta?.ita_rank_official!=null?Number(meta.ita_rank_official):null;
        const physicalProjected=meta?.projected_rank!=null?Number(meta.projected_rank):null;
        const ncaaRankType=physicalOfficial!=null
          ?"official"
          :physicalProjected!=null
            ?"simulated_depth"
            :(metaHasRank&&meta?.ita_rank!=null?"verified_other":"profile");
        const officialRank=physicalOfficial!=null
          ?physicalOfficial
          :(ncaaRankType==="verified_other"?rawRegistryRank:(metaHasRank?null:(p.ncaa_rank??null)));
        const projectedRank=physicalProjected;
        byId.set(id,{
          ...p,
          ncaa_rank:officialRank,
          ncaa_projected_rank:projectedRank,
          ncaa_registry_rank:rawRegistryRank,
          ncaa_school:canonicalNcaaSchool(p,meta?.school??p.ncaa_school??p.ncaa_last_school??null),
          ncaa_division:meta?.division??p.ncaa_division??"NCAA Division I",
          ncaa_season:meta?.season??(p.ncaa_current?ncaaSeason:null),
          ncaa_status:meta?.status??p.ncaa_status??(p.ncaa_current?"Active":"NCAA profile"),
          ncaa_snapshot_date:meta?.snapshot_date??null,
          ncaa_source:ncaaSource||null,
          ncaa_rank_type:ncaaRankType,
          ncaa_rank_verified:ncaaRankType==="official"||ncaaRankType==="verified_other",
          ncaa_current_verified:priority<=1,
          age:ageAt(p.birth_date,AGE_REFERENCE_DATE,p.age,p.age_snapshot_date),
          utr_rating:p.ncaa_utr_rating??null,
          utr_verified:Boolean(p.ncaa_utr_verified),
          utr_source:p.ncaa_utr_source??null,
          ncaa_class_year:p.ncaa_class_year??null,
          __priority:priority
        });
      };

      for(const x of officialReg.data??[]){
        const p=Array.isArray((x as any).players)?(x as any).players[0]:(x as any).players;
        put(p,x,0);
      }
      for(const x of currentReg.data??[]){
        const p=Array.isArray((x as any).players)?(x as any).players[0]:(x as any).players;
        put(p,x,1);
      }
      for(const p of currentPlayers.data??[])put(p,{ita_rank:null,season:ncaaSeason,status:"Active pool"},2);
      for(const x of allAmericanReg.data??[]){
        const p=Array.isArray((x as any).players)?(x as any).players[0]:(x as any).players;
        put(p,{...x,ita_rank:null},3);
      }
      for(const x of [...(registryPool0.data??[]),...(registryPool1.data??[]),...(registryPool2.data??[]),...(registryPool3.data??[])]){
        const p=Array.isArray((x as any).players)?(x as any).players[0]:(x as any).players;
        if(String(p?.data_source||"").startsWith("hidden duplicate merged into "))continue;
        put(p,x,4);
      }

      let rows=[...byId.values()];
      if(q){
        const nq=normalizeName(q);
        rows=rows.filter((x:any)=>normalizeName(String(x.name||"")).includes(nq));
      }
      if(country)rows=rows.filter((x:any)=>String(x.country||"").toUpperCase()===country);
      rows.sort((a:any,b:any)=>{
        const typeOrder=(x:any)=>x.ncaa_rank_type==="official"?0:x.ncaa_rank_type==="simulated_depth"?1:x.ncaa_rank!=null?2:3;
        const at=typeOrder(a),bt=typeOrder(b);
        if(at!==bt)return at-bt;
        const ar=a.ncaa_rank_type==="simulated_depth"?a.ncaa_projected_rank:a.ncaa_rank;
        const br=b.ncaa_rank_type==="simulated_depth"?b.ncaa_projected_rank:b.ncaa_rank;
        if(ar!=null||br!=null){
          const ac=Number(ar??999999),bc=Number(br??999999);
          if(ac!==bc)return ac-bc;
        }
        if(Boolean(a.ncaa_current)!==Boolean(b.ncaa_current))return a.ncaa_current?-1:1;
        return String(a.name||"").localeCompare(String(b.name||""));
      });
      const total=rows.length;
      const officialRanked=rows.filter((x:any)=>x.ncaa_rank!=null&&x.ncaa_rank_type==="official"&&String(x.ncaa_snapshot_date||"")<=gameDate).length;
      const simulatedDepth=rows.filter((x:any)=>x.ncaa_projected_rank!=null&&x.ncaa_rank_type==="simulated_depth"&&String(x.ncaa_snapshot_date||"")<=gameDate).length;
      const officialSource=(officialReg.data??[]).find((x:any)=>/ITA Division I Men.?s National Singles Rankings/i.test(String(x.source_label||""))&&x.source_url);
      rows=rows.slice(offset,offset+limit).map(({__priority,...x}:any)=>x);
      return h({
        kind,offset,limit,count:total,rows,
        officialCapacity:125,
        verifiedCurrentRanks:officialRanked,
        simulatedDepthRanks:simulatedDepth,
        officialSnapshotDate:"2025-11-25",
        officialSourceLabel:officialSource?.source_label||"ITA Division I Men's National Singles Rankings · 2025-11-25",
        officialSourceUrl:officialSource?.source_url||null,
        coverage:"ITA officiel 1-125 au 25/11/2025 · profondeur 126+ affichée uniquement comme projection Court Boss (~)",
        eligibility:"NCAA Division I · classement officiel distingué de la profondeur simulée",
        rankingDate:gameDate
      });
    }

    if(kind==="junior_doubles"){
      let query=db.from("players")
        .select("id,name,name_norm,country,is_real,game_generated,career_status,ranking,ranking_current,doubles_ranking,junior_ranking,junior_doubles_ranking,junior_doubles_points,junior_doubles_snapshot_date,junior_doubles_source,age,age_source,age_snapshot_date,birth_date,current_ability,potential,form,fitness,morale,fatigue,style,data_source,photo_url,ncaa_current,ncaa_school,ncaa_rank",{count:"exact"})
        .not("junior_doubles_ranking","is",null)
        .or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*");
      if(q)query=query.ilike("name_norm",`%${normalizeName(q)}%`);
      if(country)query=query.eq("country",country);
      query=query.order("junior_doubles_ranking",{ascending:true}).range(offset,offset+limit-1);
      const {data,error,count}=await query;
      if(error)return h({error:error.message},500);
      const ids=(data??[]).map((p:any)=>Number(p.id)).filter(Boolean);
      const simpleRanks=ids.length
        ?await db.from("junior_display_pool").select("player_id,display_rank").in("player_id",ids)
        :{data:[],error:null};
      if(simpleRanks.error)return h({error:simpleRanks.error.message},500);
      const simpleById=new Map((simpleRanks.data??[]).map((x:any)=>[Number(x.player_id),Number(x.display_rank)]));
      const rows=(data??[]).map((p:any)=>({
        ...p,
        junior_ranking:simpleById.get(Number(p.id))??p.junior_ranking??null,
        age:ageAt(p.birth_date,AGE_REFERENCE_DATE,p.age,p.age_snapshot_date),
        official_ranking:p.ranking_current?p.ranking:null
      }));
      return h({
        kind,offset,limit,count:count??0,rows,
        eligibility:"Court Boss Junior Doubles · joueurs du vivier Junior classés 1–2000",
        rankingDate:"2025-12-01",
        simulated:true
      });
    }

    if(kind==="junior"){
      let juniorQuery=db.from("junior_display_pool_view").select("*",{count:"exact"});
      if(q)juniorQuery=juniorQuery.ilike("name_norm",`%${normalizeName(q)}%`);
      if(country)juniorQuery=juniorQuery.eq("country",country);
      juniorQuery=juniorQuery.order("display_order",{ascending:true}).range(offset,offset+limit-1);

      const [page,officialCount,simulatedCount,nrCount,generatedTotal] = await Promise.all([
        juniorQuery,
        db.from("junior_display_pool").select("player_id",{count:"exact",head:true}).eq("rank_type","official"),
        db.from("junior_display_pool").select("player_id",{count:"exact",head:true}).eq("rank_type","simulated"),
        db.from("junior_display_pool").select("player_id",{count:"exact",head:true}).eq("rank_type","verified_nr"),
        db.from("players").select("id",{count:"exact",head:true})
          .eq("game_generated",true).eq("career_status","active")
          .gte("age",13).lte("age",17)
          .or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*")
      ]);
      const e=page.error||officialCount.error||simulatedCount.error||nrCount.error||generatedTotal.error;
      if(e)return h({error:e.message},500);

      const rows=(page.data??[]).map((p:any)=>({
        ...p,
        junior_points:Number(p.junior_points||0)+Number(p.junior_game_points||0),
        junior_ranking:p.display_rank==null?null:Number(p.display_rank),
        junior_rank_type:p.rank_type,
        junior_snapshot_date:p.junior_rank_snapshot_date??p.junior_snapshot_date,
        junior_source:p.junior_rank_source??p.junior_source,
        junior_source_url:p.junior_rank_source_url??null,
        age:ageAt(p.birth_date,AGE_REFERENCE_DATE,p.age,p.age_snapshot_date),
        official_ranking:p.ranking_current?p.ranking:null,
        world_rank:p.game_world_rank,
        junior_status:p.rank_type==="official"
          ?"ITF vérifié"
          :p.rank_type==="verified_nr"
            ?"ITF vérifié · NR"
            :"Newgen simulé"
      }));

      const rankedReal=Number(officialCount.count||0);
      const unrankedReal=Number(nrCount.count||0);
      const generated=Number(simulatedCount.count||0);
      return h({
        kind,offset,limit,count:page.count??0,rows,
        officialRealCount:rankedReal+unrankedReal,
        officialRankedCount:rankedReal,
        verifiedUnrankedCount:unrankedReal,
        generatedCount:generated,
        generatedReserve:Math.max(0,Number(generatedTotal.count||0)-generated),
        verifiedProfiles:rankedReal+unrankedReal,
        eligibility:"ITF Juniors · vrais profils vérifiés + 1 200 newgens classés 13–17 + réserve dynamique",
        rankingDate:AGE_REFERENCE_DATE
      });
    }


    let orderCol=kind==="singles"?"game_world_rank":"ranking";
    if(kind==="doubles") orderCol="doubles_ranking";
    if(kind==="race") orderCol="race_ranking";
    if(kind==="nextgen") orderCol="nextgen_ranking";
    if(kind==="itf") orderCol="itf_ranking";
    if(kind==="junior") orderCol="junior_ranking";
    let query=db.from("players")
      .select("id,name,country,is_real,game_generated,career_status,ranking,source_ranking,game_world_rank,points,ranking_snapshot_date,previous_ranking,rank_change,ranking_previous,ranking_change,best_rank_2025,career_high_rank,career_high_rank_date,weeks_at_no1,weeks_top10,weeks_top100,ranking_history_weeks,ranking_history_source,ranking_history_cutoff,doubles_ranking,doubles_points,doubles_snapshot_date,doubles_source,race_ranking,race_points,race_snapshot_date,race_source,nextgen_ranking,nextgen_points,nextgen_snapshot_date,nextgen_source,nextgen_status,itf_ranking,junior_ranking,junior_points,junior_snapshot_date,junior_source,junior_doubles_ranking,junior_doubles_points,junior_doubles_snapshot_date,junior_doubles_source,age,age_source,age_snapshot_date,birth_date,current_ability,potential,form,fitness,morale,fatigue,style,data_source,data_snapshot,ranking_source,ranking_current,photo_url,ncaa_current,ncaa_school,ncaa_division,ncaa_rank,ncaa_status,ncaa_last_school,ncaa_verified",{count:"exact"})
      .or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*");
    if(kind==="singles"){
      query=query.not("game_world_rank","is",null).lte("game_world_rank",30000);
    } else {
      query=query.not(orderCol,"is",null).eq("is_real",true);
    }
    if(kind==="doubles") query=query.not("doubles_ranking","is",null).or(`doubles_snapshot_date.is.null,doubles_snapshot_date.lte.${gameDate}`);
    if(kind==="race") query=query.not("race_source","is",null).or(`race_snapshot_date.is.null,race_snapshot_date.lte.${gameDate}`);
    if(kind==="nextgen"){
      query=query.not("nextgen_source","is",null).not("age","is",null).lte("age",nextGenU).or(`nextgen_snapshot_date.is.null,nextgen_snapshot_date.lte.${gameDate}`);
    }
    if(kind==="junior"){
      query=query.not("junior_source","is",null).not("junior_ranking","is",null).gte("age",13).lte("age",18);
    }
    if(q) query=query.ilike("name_norm",`%${normalizeName(q)}%`);
    if(country) query=query.eq("country",country);
    query=query.order(orderCol,{ascending:true}).range(offset,offset+limit-1);
    const {data,error,count}=await query;
    if(error) return h({error:error.message},500);
    const rows=(data??[]).map((p:any)=>({...p,age:ageAt(p.birth_date,AGE_REFERENCE_DATE,p.age,p.age_snapshot_date),doubles_verified:!!p.doubles_source,official_ranking:p.ranking_current?p.ranking:null,world_rank:p.game_world_rank}));
    return h({kind,offset,limit,count:count??0,rows,eligibility:kind==="nextgen"?"U"+nextGenU+" · ATP Next Gen Race · base 01/12/2025":kind==="junior"?"ITF Juniors · DOB vérifiée":null});
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
    const gameDate=String(careerDateRes.data?.career_date||AGE_REFERENCE_DATE);

    if(circuit==="Junior"){
      let juniorQuery=db.from("junior_display_pool_view").select("*",{count:"exact"})
        .gte("potential",potentialMin);
      if(q)juniorQuery=juniorQuery.ilike("name_norm",`%${normalizeName(q)}%`);
      if(country)juniorQuery=juniorQuery.eq("country",country);
      if(ageMax<99)juniorQuery=juniorQuery.lte("age",ageMax);
      juniorQuery=juniorQuery.order("display_order",{ascending:true}).range(offset,offset+limit-1);
      const page=await juniorQuery;
      if(page.error)return h({error:page.error.message},500);
      const rows=(page.data??[]).map((p:any)=>({
        ...p,
        junior_ranking:p.display_rank,
        junior_rank_type:p.rank_type,
        junior_snapshot_date:p.junior_rank_snapshot_date,
        junior_source:p.junior_rank_source,
        age:ageAt(p.birth_date,AGE_REFERENCE_DATE,p.age,p.age_snapshot_date)
      }));
      return h({q,country,circuit,age_max:ageMax,potential_min:potentialMin,offset,limit,count:page.count??0,rows,verifiedJuniorPool:true,cutoff:AGE_REFERENCE_DATE});
    }

    let query=db.from("players")
      .select("id,name,country,is_real,ranking,game_world_rank,points,doubles_ranking,doubles_points,doubles_snapshot_date,doubles_source,race_ranking,race_points,race_snapshot_date,race_source,nextgen_ranking,nextgen_points,nextgen_snapshot_date,nextgen_source,itf_ranking,junior_ranking,junior_points,junior_snapshot_date,junior_source,junior_doubles_ranking,junior_doubles_points,junior_doubles_snapshot_date,junior_doubles_source,age,age_source,age_snapshot_date,birth_date,birth_date_source,height_cm,handedness,backhand,backhand_source,backhand_verified,current_ability,potential,form,fitness,morale,fatigue,style,scouting_confidence,ranking_current,ranking_snapshot_date,ranking_source,career_high_rank,career_high_rank_date,weeks_at_no1,weeks_top10,weeks_top100,ranking_history_weeks,ranking_history_source,ranking_history_cutoff,data_source,circuits_2025,sackmann_id,wikidata_id,photo_url,ncaa_current,ncaa_school,ncaa_division,ncaa_rank,ncaa_status,ncaa_last_school,ncaa_verified",{count:"exact"})
      .gte("potential",potentialMin).or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*");
    if(ageMax<99) query=query.lte("age",ageMax);

    if(q) query=query.ilike("name_norm",`%${normalizeName(q)}%`);
    if(country) query=query.eq("country",country);
    if(circuit==="ATP"||circuit==="ATP classés") query=query.eq("ranking_current",true);
    if(circuit==="ATP profond") query=query.eq("is_real",true).not("ranking","is",null);
    if(circuit==="Tous réels") query=query.eq("is_real",true);
    if(circuit==="Double") query=query.not("doubles_ranking","is",null).or(`doubles_snapshot_date.is.null,doubles_snapshot_date.lte.${gameDate}`);
    if(circuit==="Junior Double") query=query.not("junior_doubles_ranking","is",null).or(`junior_doubles_snapshot_date.is.null,junior_doubles_snapshot_date.lte.${gameDate}`);
    if(circuit==="Race") query=query.not("race_ranking","is",null).not("race_source","is",null).or(`race_snapshot_date.is.null,race_snapshot_date.lte.${gameDate}`);
    if(circuit==="Next Gen") query=query.not("nextgen_ranking","is",null).not("nextgen_source","is",null).not("age","is",null).lte("age",21).or(`nextgen_snapshot_date.is.null,nextgen_snapshot_date.lte.${gameDate}`);
    if(circuit==="ITF") query=query.not("itf_ranking","is",null);
    if(circuit==="Junior") query=query.not("junior_ranking","is",null).not("junior_source","is",null).gte("age",13).lte("age",18);
    if(circuit==="NCAA") query=query.eq("ncaa_current",true);
    if(circuit==="Prospects") query=query.eq("is_real",false).gte("potential",Math.max(70,potentialMin));

    if(circuit==="ATP"||circuit==="ATP classés"||circuit==="ATP profond") query=query.order("ranking",{ascending:true,nullsFirst:false});
    else if(q&&circuit==="Tous") query=query.order("name",{ascending:true});
    else if(circuit==="Tous réels") query=query.order("name",{ascending:true});
    else if(circuit==="Double") query=query.order("doubles_ranking",{ascending:true,nullsFirst:false});
    else if(circuit==="Junior Double") query=query.order("junior_doubles_ranking",{ascending:true,nullsFirst:false});
    else if(circuit==="Race") query=query.order("race_ranking",{ascending:true,nullsFirst:false});
    else if(circuit==="Next Gen") query=query.order("nextgen_ranking",{ascending:true,nullsFirst:false});
    else if(circuit==="ITF") query=query.order("itf_ranking",{ascending:true,nullsFirst:false});
    else if(circuit==="Junior") query=query.order("junior_ranking",{ascending:true,nullsFirst:false});
    else if(circuit==="NCAA") query=query.order("ncaa_current",{ascending:false}).order("ncaa_rank",{ascending:true,nullsFirst:false}).order("name",{ascending:true});
    else query=query.order("potential",{ascending:false}).order("current_ability",{ascending:false});

    query=query.range(offset,offset+limit-1);
    const {data,error,count}=await query;
    if(error)return h({error:error.message},500);
    let rows=(data??[]).map((p:any)=>({...p,age:ageAt(p.birth_date,AGE_REFERENCE_DATE,p.age,p.age_snapshot_date)}));
    const ncaaBrowseIds=rows.filter((p:any)=>p.ncaa_current||p.ncaa_verified).map((p:any)=>Number(p.id)).filter(Boolean);
    if(ncaaBrowseIds.length){
      const registry=await db.from("ncaa_player_registry")
        .select("player_id,ita_rank,ita_rank_official,projected_rank,school,status,snapshot_date,source_label,source_url")
        .in("player_id",ncaaBrowseIds)
        .lte("snapshot_date",gameDate)
        .order("snapshot_date",{ascending:false});
      if(registry.error)return h({error:registry.error.message},500);
      const latestByPlayer=new Map<number,any>();
      for(const x of registry.data??[]){
        const pid=Number((x as any).player_id||0);
        if(pid&&!latestByPlayer.has(pid))latestByPlayer.set(pid,x);
      }
      rows=rows.map((p:any)=>{
        const x:any=latestByPlayer.get(Number(p.id));
        if(!x)return p;
        const official=x.ita_rank_official!=null?Number(x.ita_rank_official):null;
        const projected=x.projected_rank!=null?Number(x.projected_rank):null;
        return {
          ...p,
          ncaa_rank:official??projected??p.ncaa_rank,
          ncaa_official_rank:official,
          ncaa_projected_rank:projected,
          ncaa_rank_type:official!=null?"official":projected!=null?"simulated_depth":"verified_other",
          ncaa_rank_source:x.source_label||x.source_url||null,
          ncaa_rank_source_url:x.source_url||null,
          ncaa_school:x.school||p.ncaa_school
        };
      });
    }
    // Search/browse progressively replaces Court Boss fictive estimates with sourced public facts when available.
    // ATP is already complete; NCAA/ITF pages hydrate a few missing profiles on every browse.
    if(q.length>=2||["NCAA","ITF","Junior","Junior Double"].includes(circuit)){
      const enrich=rows.filter((p:any)=>p.is_real&&(!p.birth_date||!p.photo_url||!p.wikidata_id||!p.backhand_verified)).slice(0,q.length>=2?4:2);
      if(enrich.length){
        const enriched=await Promise.all(enrich.map((p:any)=>resolvePlayerFacts({...p},gameDate)));
        const byId=new Map(enriched.map((p:any)=>[Number(p.id),p]));
        rows=rows.map((p:any)=>byId.get(Number(p.id))??p).map((p:any)=>({...p,age:ageAt(p.birth_date,AGE_REFERENCE_DATE,p.age,p.age_snapshot_date)}));
      }
    }
    return h({q,country,circuit,age_max:ageMax,potential_min:potentialMin,offset,limit,count:count??0,rows});
  }

  const baselineLockedImports=[
    "/api/scrape-real-junior-profiles",
    "/api/scrape-real-juniors",
    "/api/sync-junior-demographics",
    "/api/sync-real-juniors"
  ];
  if(req.method==="GET"&&baselineLockedImports.some((x)=>path.endsWith(x))){
    return h({
      error:"Base figée au 01/12/2025 : imports live post-cutoff désactivés.",
      cutoff:AGE_REFERENCE_DATE,
      mode:"historical_baseline"
    },409);
  }

  if(path.endsWith("/api/scrape-real-junior-profiles")&&req.method==="GET"){
    try{return h(await scrapeRealJuniorStatProfiles())}
    catch(e){return h({error:String((e as any)?.message||e)},500)}
  }

  if(path.endsWith("/api/scrape-real-juniors")&&req.method==="GET"){
    try{
      const sources=[
        "https://www.coretennis.net/majic/pageServer/160101003i/en/ITF-Junior-Boys-Rankings.html",
        "https://www.coretennis.net/majic/pageServer/0n0100005a/en/ITF-Junior-Boys-Best-Progression--Year-.html",
        "https://www.coretennis.net/majic/pageServer/170100003k/en/ITF-Junior-Boys-Best-Progression--Week-.html",
        "https://www.coretennis.net/majic/pageServer/0p0100005b/en/ITF-Junior-Boys-Biggest-Drop--Year-.html",
        "https://www.coretennis.net/majic/pageServer/190100003l/en/ITF-Junior-Boys-Biggest-Drop--Week-.html",
        "https://www.coretennis.net/majic/pageServer/1i010100fo/en/ITF-Junior-Boys-Biggest-Drop--6-Months-.html"
      ];
      const settled=await Promise.allSettled(sources.map(fetchCoreTennisJuniorRows));
      const merged=new Map<string,any>(),stats:any[]=[];
      let snapshot="2026-09-21";
      for(let i=0;i<settled.length;i++){
        const r=settled[i];
        if(r.status==="rejected"){stats.push({url:sources[i],ok:false,error:String((r.reason as any)?.message||r.reason)});continue;}
        stats.push({url:sources[i],ok:true,rows:r.value.length,snapshot:r.value[0]?.snapshot||null});
        for(const p of r.value){
          if(p.snapshot&&String(p.snapshot)>snapshot)snapshot=String(p.snapshot);
          const key=normalizeName(p.name)+"|"+p.country;
          const prev=merged.get(key);
          if(!prev||p.ranking<prev.ranking)merged.set(key,p);
        }
      }
      const stageRows=[...merged.values()].map((p:any)=>({
        name_norm:normalizeName(p.name),country:p.country,name:p.name,
        junior_ranking:p.ranking,snapshot_date:snapshot,source_url:p.url,
        source_label:"CoreTennis ITF Junior Boys · "+snapshot,updated_at:new Date().toISOString()
      }));
      for(let i=0;i<stageRows.length;i+=500){
        const up=await db.from("junior_real_staging").upsert(stageRows.slice(i,i+500),{onConflict:"name_norm,country"});
        if(up.error)throw up.error;
      }
      return h({snapshot,discovered:merged.size,staged:stageRows.length,sources:stats,rows:[...merged.values()].map((p:any)=>({name:p.name,country:p.country,ranking:p.ranking}))});
    }catch(e){return h({error:String((e as any)?.message||e)},500)}
  }

  if(path.endsWith("/api/sync-career-ranking-history")&&req.method==="GET"){
    try{
      const decade=String(u.searchParams.get("decade")||"20s");
      const reset=u.searchParams.get("reset")==="1";
      return h(await syncSackmannRankingDecade(decade,reset));
    }catch(e){return h({error:String((e as any)?.message||e)},500)}
  }
  if(path.endsWith("/api/sync-atp-career-titles")&&req.method==="GET"){
    try{
      const from=n(u.searchParams.get("from"),2020,1968,2025);
      const to=n(u.searchParams.get("to"),2025,from,2025);
      return h(await syncSackmannAtpTitles(from,to));
    }catch(e){return h({error:String((e as any)?.message||e)},500)}
  }

  if(path.endsWith("/api/sync-junior-demographics")&&req.method==="GET"){
    try{return h(await syncJuniorDemographics())}
    catch(e){return h({error:String((e as any)?.message||e)},500)}
  }

  if(path.endsWith("/api/sync-real-juniors")&&req.method==="GET"){
    try{return h(await syncRealJuniorBoys())}
    catch(e){return h({error:String((e as any)?.message||e)},500)}
  }


  if(path.endsWith("/api/ncaa-universities")&&req.method==="GET"){
    const season="2025-26";
    const snapshot="2025-11-25";
    const cutoff="2025-12-01";
    const schoolParam=(u.searchParams.get("school")??"").trim().slice(0,180);
    const q=(u.searchParams.get("q")??"").trim().slice(0,100);
    const schoolKey=(v:any)=>normalizeName(String(v||""));
    const profileKey=(v:any)=>schoolKey(v).replace(/\s+/g,"");

    const [rosterRes,stagingRes,mapRes,profilesRes]=await Promise.all([
      db.from("ncaa_roster_reference")
        .select("athlete_id,full_name,name_norm,season,division,conference,school,class_standing,country,source_url,player_id")
        .eq("season",season).limit(5000),
      db.from("ita_ncaa_singles_staging")
        .select("ita_rank,player_name,ita_player_id,school,conference,ranking_points,wins,losses")
        .eq("season",season).eq("snapshot_date",snapshot).limit(200),
      db.from("ita_ncaa_singles_player_map")
        .select("ita_player_id,player_id")
        .eq("season",season).eq("snapshot_date",snapshot).limit(200),
      db.from("ncaa_university_profiles")
        .select("*").limit(1000)
    ]);
    const baseError=rosterRes.error||stagingRes.error||mapRes.error||profilesRes.error;
    if(baseError)return h({error:baseError.message},500);

    const rosterAll=rosterRes.data??[];
    const stagingAll=stagingRes.data??[];
    const playerByIta=new Map<string,number>((mapRes.data??[]).map((x:any)=>[String(x.ita_player_id),Number(x.player_id)]));
    const profileByKey=new Map<string,any>((profilesRes.data??[]).map((x:any)=>[String(x.school_key),x]));
    const rosterSchoolByPlayer=new Map<number,string>();
    const rosterDisplayByKey=new Map<string,string>();
    for(const rr of rosterAll){
      const key=schoolKey((rr as any).school);
      if(key&&!rosterDisplayByKey.has(key))rosterDisplayByKey.set(key,String((rr as any).school||""));
      if((rr as any).player_id!=null&&key)rosterSchoolByPlayer.set(Number((rr as any).player_id),key);
    }

    const stageSchoolVotes=new Map<string,Map<string,number>>();
    for(const s of stagingAll){
      const rawKey=schoolKey((s as any).school);
      const playerId=playerByIta.get(String((s as any).ita_player_id||""));
      const rosterKey=playerId?rosterSchoolByPlayer.get(playerId):null;
      if(!rawKey||!rosterKey)continue;
      const votes=stageSchoolVotes.get(rawKey)||new Map<string,number>();
      votes.set(rosterKey,(votes.get(rosterKey)||0)+1);
      stageSchoolVotes.set(rawKey,votes);
    }
    const stageSchoolKeyMap=new Map<string,string>();
    for(const [rawKey,votes] of stageSchoolVotes){
      const winner=[...votes.entries()].sort((a,b)=>b[1]-a[1]||a[0].localeCompare(b[0]))[0]?.[0];
      if(winner)stageSchoolKeyMap.set(rawKey,winner);
    }
    const explicitStageAliases=new Map<string,string>([
      [schoolKey("Baylor University"),schoolKey("Baylor")],
      [schoolKey("Florida State"),schoolKey("Florida St.")],
      [schoolKey("Michigan State"),schoolKey("Michigan St.")],
      [schoolKey("Texas A&M University"),schoolKey("Texas A&M")],
      [schoolKey("University Of Arizona"),schoolKey("Arizona")],
      [schoolKey("University Of Georgia"),schoolKey("Georgia")],
      [schoolKey("University of Oklahoma"),schoolKey("Oklahoma")],
      [schoolKey("Wichita State"),schoolKey("Wichita St.")]
    ]);
    for(const [rawKey,rosterKey] of explicitStageAliases){
      if(rosterDisplayByKey.has(rosterKey))stageSchoolKeyMap.set(rawKey,rosterKey);
    }
    const stagingSchoolKey=(s:any)=>{
      const raw=schoolKey(s?.school);
      return stageSchoolKeyMap.get(raw)||raw;
    };

    const fetchAtpSnapshot=async(ids:number[])=>{
      const unique=[...new Set(ids.filter((x:any)=>Number.isFinite(Number(x))&&Number(x)>0).map(Number))];
      if(!unique.length)return new Map<number,any>();
      const chunks:number[][]=[];
      for(let i=0;i<unique.length;i+=350)chunks.push(unique.slice(i,i+350));
      const results=await Promise.all(chunks.map(chunk=>
        db.from("ranking_history").select("player_id,ranking,points,snapshot_date")
          .eq("snapshot_date",cutoff).in("player_id",chunk).limit(1000)
      ));
      const err=results.find(x=>x.error)?.error;
      if(err)throw err;
      const out=new Map<number,any>();
      for(const res of results)for(const row of res.data??[])out.set(Number((row as any).player_id),row);
      return out;
    };

    if(!schoolParam){
      let atpById=new Map<number,any>();
      try{atpById=await fetchAtpSnapshot(rosterAll.map((x:any)=>Number(x.player_id)).filter(Boolean))}catch{}
      const bySchool=new Map<string,any>();
      const ensure=(key:any,raw:any)=>{
        const k=String(key||"");
        if(!k)return null;
        let row=bySchool.get(k);
        if(!row){
          const display=rosterDisplayByKey.get(k)||String(raw||"").trim();
          const profile=profileByKey.get(profileKey(display))||profileByKey.get(profileKey(raw));
          row={
            key:k,name:display,roster_count:0,official_ranked_count:0,best_ita_rank:null,
            atp_ranked_count:0,best_atp_rank:null,conference:null,division:null,source_url:null,
            city:profile?.city||null,state:profile?.state||null,country:profile?.country||"USA",
            description:profile?.description||null,hero_image_url:profile?.hero_image_url||null,
            logo_url:profile?.logo_url||null,primary_color:profile?.primary_color||null,
            secondary_color:profile?.secondary_color||null,_atpIds:new Set<number>()
          };
          bySchool.set(k,row);
        }
        return row;
      };
      for(const rr of rosterAll){
        const key=schoolKey((rr as any).school);
        const row=ensure(key,(rr as any).school); if(!row)continue;
        row.roster_count++;
        row.conference=row.conference||(rr as any).conference||null;
        row.division=row.division||(rr as any).division||"NCAA Division I";
        row.source_url=row.source_url||(rr as any).source_url||null;
        const pid=Number((rr as any).player_id||0);
        const atp=pid?atpById.get(pid):null;
        if(atp&&!row._atpIds.has(pid)){
          row._atpIds.add(pid);row.atp_ranked_count++;
          const rank=Number(atp.ranking||0)||null;
          if(rank!=null&&(row.best_atp_rank==null||rank<row.best_atp_rank))row.best_atp_rank=rank;
        }
      }
      for(const s of stagingAll){
        const key=stagingSchoolKey(s);
        const row=ensure(key,(s as any).school); if(!row)continue;
        const rank=Number((s as any).ita_rank||0)||null;
        row.official_ranked_count++;
        if(rank!=null&&(row.best_ita_rank==null||rank<row.best_ita_rank))row.best_ita_rank=rank;
        row.conference=row.conference||(s as any).conference||null;
        row.division=row.division||"NCAA Division I";
        const pid=playerByIta.get(String((s as any).ita_player_id||""));
        const atp=pid?atpById.get(pid):null;
        if(atp&&pid&&!row._atpIds.has(pid)){
          row._atpIds.add(pid);row.atp_ranked_count++;
          const ar=Number(atp.ranking||0)||null;
          if(ar!=null&&(row.best_atp_rank==null||ar<row.best_atp_rank))row.best_atp_rank=ar;
        }
      }
      let rows=[...bySchool.values()].map((x:any)=>{
        const {_atpIds,...row}=x;
        const fallbackDescription=
          row.name+" évolue en "+String(row.division||"NCAA Division I")+
          (row.conference?" dans la "+String(row.conference):"")+
          ". Court Boss recense "+String(row.roster_count||0)+" joueur(s) dans le roster 2025-26"+
          (row.official_ranked_count?", dont "+String(row.official_ranked_count)+" classé(s) ITA.":".");
        let favicon_url:any=null;
        try{favicon_url=row.source_url?new URL("/favicon.ico",row.source_url).toString():null}catch{}
        return {...row,description:row.description||fallbackDescription,favicon_url};
      });
      if(q){
        const nq=normalizeName(q);
        rows=rows.filter((x:any)=>
          normalizeName(x.name).includes(nq)||normalizeName(x.conference||"").includes(nq)||normalizeName(x.state||"").includes(nq)
        );
      }
      rows.sort((a:any,b:any)=>{
        const ar=Number(a.best_ita_rank??999999),br=Number(b.best_ita_rank??999999);
        if(ar!==br)return ar-br;
        if(Number(b.roster_count)!==Number(a.roster_count))return Number(b.roster_count)-Number(a.roster_count);
        return String(a.name).localeCompare(String(b.name));
      });
      return h({
        kind:"ncaa-universities",season,snapshot_date:snapshot,cutoff,
        count:rows.length,rows,rosterRows:rosterAll.length,officialRankedPlayers:stagingAll.length,
        conferences:[...new Set(rows.map((x:any)=>String(x.conference||"")).filter(Boolean))].sort()
      });
    }

    const targetKey=schoolKey(schoolParam);
    const rosterRows=rosterAll.filter((x:any)=>schoolKey(x.school)===targetKey);
    const stagedRows=stagingAll.filter((x:any)=>stagingSchoolKey(x)===targetKey);
    const stagedIds=new Set(stagedRows.map((x:any)=>String(x.ita_player_id||"")).filter(Boolean));
    const mappedPlayerByIta=new Map<string,number>(
      [...playerByIta.entries()].filter(([ita])=>stagedIds.has(ita))
    );
    const ids=new Set<number>();
    for(const rr of rosterRows)if((rr as any).player_id!=null)ids.add(Number((rr as any).player_id));
    for(const s of stagedRows){
      const id=mappedPlayerByIta.get(String((s as any).ita_player_id||""));
      if(id)ids.add(id);
    }
    const playerIds=[...ids];

    let playerData:any[]=[];
    let registryData:any[]=[];
    let rankingHistory:any[]=[];
    if(playerIds.length){
      const [pRes,rRes,hRes]=await Promise.all([
        db.from("players")
          .select("id,name,country,birth_date,age,age_snapshot_date,ranking,ranking_current,ranking_snapshot_date,ncaa_utr_rating,ncaa_utr_verified,ncaa_current,ncaa_status")
          .in("id",playerIds).limit(500),
        db.from("ncaa_player_registry")
          .select("player_id,ita_rank_official,projected_rank,status,snapshot_date")
          .eq("season",season).in("player_id",playerIds).lte("snapshot_date",cutoff).limit(1000),
        db.from("ranking_history")
          .select("player_id,snapshot_date,ranking,points")
          .in("player_id",playerIds).eq("snapshot_date",cutoff).limit(500)
      ]);
      const detailError=pRes.error||rRes.error||hRes.error;
      if(detailError)return h({error:detailError.message},500);
      playerData=pRes.data??[];registryData=rRes.data??[];rankingHistory=hRes.data??[];
    }

    const playerById=new Map<number,any>(playerData.map((x:any)=>[Number(x.id),x]));
    const atpById=new Map<number,any>(rankingHistory.map((x:any)=>[Number(x.player_id),x]));
    const regById=new Map<number,any>();
    for(const r of registryData){
      const id=Number((r as any).player_id),old=regById.get(id);
      const score=(r as any).ita_rank_official!=null?0:(r as any).projected_rank!=null?1:2;
      const oldScore=old?(old.ita_rank_official!=null?0:old.projected_rank!=null?1:2):99;
      if(!old||score<oldScore||String((r as any).snapshot_date||"")>String(old.snapshot_date||""))regById.set(id,r);
    }
    const stagedByPlayerId=new Map<number,any>();
    for(const s of stagedRows){
      const id=mappedPlayerByIta.get(String((s as any).ita_player_id||""));
      if(id)stagedByPlayerId.set(id,s);
    }

    const merged=new Map<string,any>();
    const put=(base:any,playerId:any=null)=>{
      const id=playerId!=null?Number(playerId):null;
      const p=id?playerById.get(id):null;
      const st=id?stagedByPlayerId.get(id):null;
      const reg=id?regById.get(id):null;
      const atp=id?atpById.get(id):null;
      const name=String(p?.name||st?.player_name||base?.full_name||"").trim();
      if(!name)return;
      const key=id?"id:"+id:"name:"+normalizeName(name);
      const existing=merged.get(key)||{};
      const age=ageAt(p?.birth_date||null,cutoff,p?.age,p?.age_snapshot_date);
      merged.set(key,{
        ...existing,id:id||null,name,country:p?.country||base?.country||null,
        class_standing:base?.class_standing||existing.class_standing||null,
        division:base?.division||"NCAA Division I",conference:base?.conference||existing.conference||null,
        university:String(base?.school||rosterDisplayByKey.get(targetKey)||schoolParam),
        ita_rank:st?.ita_rank??reg?.ita_rank_official??existing.ita_rank??null,
        projected_rank:reg?.projected_rank??existing.projected_rank??null,
        atp_rank:atp?.ranking??null,atp_points:atp?.points??null,
        utr_rating:p?.ncaa_utr_rating??null,utr_verified:Boolean(p?.ncaa_utr_verified),
        age,ncaa_current:Boolean(p?.ncaa_current??true),
        ncaa_status:p?.ncaa_status||reg?.status||"Active",
        source_url:base?.source_url||existing.source_url||null
      });
    };
    for(const rr of rosterRows)put(rr,(rr as any).player_id);
    for(const s of stagedRows){
      const id=mappedPlayerByIta.get(String((s as any).ita_player_id||""));
      put({school:rosterDisplayByKey.get(targetKey)||schoolParam,conference:(s as any).conference,division:"NCAA Division I"},id||null);
    }

    const rows=[...merged.values()].sort((a:any,b:any)=>{
      const ar=Number(a.ita_rank??999999),br=Number(b.ita_rank??999999);
      if(ar!==br)return ar-br;
      const aa=Number(a.atp_rank??999999),ba=Number(b.atp_rank??999999);
      if(aa!==ba)return aa-ba;
      return String(a.name).localeCompare(String(b.name));
    });

    const displayName=rosterDisplayByKey.get(targetKey)||rosterRows[0]?.school||stagedRows[0]?.school||schoolParam;
    const pkey=profileKey(displayName);
    let profile=profileByKey.get(pkey)||null;
    const conference=rosterRows.find((x:any)=>x.conference)?.conference||stagedRows.find((x:any)=>x.conference)?.conference||profile?.conference||null;
    const division=rosterRows[0]?.division||profile?.division||"NCAA Division I";
    const sourceUrl=profile?.source_url||rosterRows.find((x:any)=>x.source_url)?.source_url||null;
    const officialCount=rows.filter((x:any)=>x.ita_rank!=null).length;
    const atpCount=rows.filter((x:any)=>x.atp_rank!=null).length;
    const bestIta=rows.find((x:any)=>x.ita_rank!=null)?.ita_rank??null;
    const bestAtp=rows.filter((x:any)=>x.atp_rank!=null).reduce((m:any,x:any)=>m==null||Number(x.atp_rank)<m?Number(x.atp_rank):m,null);
    const generatedDescription=
      displayName+" évolue en "+division+(conference?" dans la "+conference:"")+
      ". Le roster Court Boss 2025-26 contient "+String(rows.length)+" joueur(s), avec "+
      String(officialCount)+" classé(s) ITA"+(bestIta!=null?" et un meilleur rang ITA #"+String(bestIta):"")+
      ". "+String(atpCount)+" joueur(s) disposent d'un classement ATP au cutoff du 01/12/2025"+
      (bestAtp!=null?", le meilleur étant #"+String(bestAtp):"")+".";

    const absoluteUrl=(raw:any,base:any)=>{
      const value=String(raw||"").trim();
      if(!value)return null;
      try{return new URL(value,String(base||sourceUrl||"")).toString()}catch{return null}
    };
    const extractMeta=(html:string,name:string)=>{
      const safe=String(name).replace(/[.*+?^$()|[\]\\]/g,"\\$&");
      const a=new RegExp('<meta[^>]+(?:property|name)=[\"\\\']'+safe+'[\"\\\'][^>]+content=[\"\\\']([^\"\\\']+)[\"\\\']','i').exec(html)?.[1];
      if(a)return htmlText(a);
      const b=new RegExp('<meta[^>]+content=[\"\\\']([^\"\\\']+)[\"\\\'][^>]+(?:property|name)=[\"\\\']'+safe+'[\"\\\']','i').exec(html)?.[1];
      return b?htmlText(b):null;
    };
    const extractIcon=(html:string)=>{
      const a=/<link[^>]+rel=["'][^"']*(?:apple-touch-icon|icon)[^"']*["'][^>]+href=["']([^"']+)["']/i.exec(html)?.[1];
      if(a)return a;
      return /<link[^>]+href=["']([^"']+)["'][^>]+rel=["'][^"']*(?:apple-touch-icon|icon)[^"']*["']/i.exec(html)?.[1]||null;
    };

    if(sourceUrl&&(!profile?.hero_image_url||!profile?.logo_url)){
      try{
        const response=await fetch(sourceUrl,{
          headers:{"User-Agent":"CourtBoss/1.0 (+NCAA university profile)","Accept":"text/html,application/xhtml+xml"},
          signal:AbortSignal.timeout(6500)
        });
        if(response.ok){
          const html=await response.text();
          const hero=absoluteUrl(extractMeta(html,"og:image")||extractMeta(html,"twitter:image"),sourceUrl);
          const logo=absoluteUrl(extractIcon(html),sourceUrl);
          const update={
            school_key:pkey,display_name:displayName,conference,division,
            description:profile?.description||generatedDescription,
            hero_image_url:hero||profile?.hero_image_url||null,
            logo_url:logo||profile?.logo_url||null,
            source_url:sourceUrl,metadata_source:"Official athletics roster page · Open Graph",
            metadata_fetched_at:new Date().toISOString(),updated_at:new Date().toISOString()
          };
          const saved=await db.from("ncaa_university_profiles").upsert(update,{onConflict:"school_key"}).select("*").maybeSingle();
          if(!saved.error&&saved.data)profile=saved.data;
        }
      }catch{}
    }

    if(!profile){
      const update={
        school_key:pkey,display_name:displayName,conference,division,
        description:generatedDescription,source_url:sourceUrl,
        metadata_source:"Court Boss NCAA roster summary",
        metadata_fetched_at:new Date().toISOString(),updated_at:new Date().toISOString()
      };
      const saved=await db.from("ncaa_university_profiles").upsert(update,{onConflict:"school_key"}).select("*").maybeSingle();
      if(!saved.error&&saved.data)profile=saved.data;
    }else if(!profile.description){
      const saved=await db.from("ncaa_university_profiles").update({description:generatedDescription,updated_at:new Date().toISOString()}).eq("school_key",pkey).select("*").maybeSingle();
      if(!saved.error&&saved.data)profile=saved.data;
    }

    let faviconUrl:any=null;
    try{faviconUrl=sourceUrl?new URL("/favicon.ico",sourceUrl).toString():null}catch{}
    return h({
      kind:"ncaa-university",season,snapshot_date:snapshot,cutoff,
      university:{
        name:displayName,conference,division,roster_count:rows.length,
        official_ranked_count:officialCount,atp_ranked_count:atpCount,
        best_ita_rank:bestIta,best_atp_rank:bestAtp,
        city:profile?.city||null,state:profile?.state||null,country:profile?.country||"USA",
        description:profile?.description||generatedDescription,
        hero_image_url:profile?.hero_image_url||null,logo_url:profile?.logo_url||null,
        favicon_url:faviconUrl,source_url:sourceUrl,
        primary_color:profile?.primary_color||null,secondary_color:profile?.secondary_color||null,
        metadata_source:profile?.metadata_source||"Court Boss NCAA roster summary"
      },
      rows
    });
  }

  if(path.endsWith("/api/ncaa-doubles")&&req.method==="GET"){
    const offset=n(u.searchParams.get("offset"),0,0,500);
    const limit=n(u.searchParams.get("limit"),100,1,100);
    const q=(u.searchParams.get("q")??"").trim().toLowerCase().slice(0,80);
    const career=await db.from("career_state").select("career_date").eq("id","demo").maybeSingle();
    const referenceDate=String(career.data?.career_date||AGE_REFERENCE_DATE);
    const latest=await db.from("ncaa_doubles_rankings").select("snapshot_date")
      .lte("snapshot_date",referenceDate).order("snapshot_date",{ascending:false}).limit(1).maybeSingle();
    if(latest.error)return h({error:latest.error.message},500);
    if(!latest.data?.snapshot_date)return h({
      kind:"ncaa-doubles",offset,limit,count:0,rows:[],officialCapacity:0,
      rankingDate:referenceDate,source:"Aucun classement NCAA double disponible avant le cutoff."
    });
    let query=db.from("ncaa_doubles_rankings")
      .select("*",{count:"exact"}).eq("snapshot_date",latest.data.snapshot_date);
    if(q) query=query.or(`player_one_name.ilike.%${q}%,player_two_name.ilike.%${q}%,school.ilike.%${q}%`);
    query=query.order("ita_rank",{ascending:true}).range(offset,offset+limit-1);
    const {data,error,count}=await query;
    if(error)return h({error:error.message},500);
    return h({
      kind:"ncaa-doubles",offset,limit,count:count??0,rows:data??[],
      officialCapacity:count??0,rankingDate:latest.data.snapshot_date,
      source:"NCAA double · dernière source disponible avant le cutoff"
    });
  }

  if(path.endsWith("/api/doubles-race")&&req.method==="GET"){
    const career=await db.from("career_state").select("career_date").eq("id","demo").maybeSingle();
    const referenceDate=String(career.data?.career_date||AGE_REFERENCE_DATE);
    const race=await db.rpc("doubles_race_for_date",{p_date:referenceDate});
    if(race.error)return h({error:race.error.message},500);
    return h({
      rows:race.data??[],count:(race.data??[]).length,
      snapshot:referenceDate,reference_date:referenceDate,
      qualificationPlaces:8,finalsName:"Nitto ATP Finals · Double"
    });
  }

  if(path.endsWith("/api/player")&&req.method==="GET"){
    let id=n(u.searchParams.get("id"),0,1,99999999);
    const requestedManagedContextId=n(u.searchParams.get("managed_context_player_id"),0,0,99999999);
    const identity=await db.from("players").select("data_source").eq("id",id).maybeSingle();
    const canonical=identity.data?.data_source?.match(/hidden duplicate merged into (\d+)/);
    if(canonical)id=Number(canonical[1]);
    const [p,sp,titles,hist,short,matches,careerStats,finals,juniorEntries,tournamentHistory,ncaa,ncaaCareer,ncaaTransfers,careerDate,legend,historicalSeasons,juniorDisplay] = await Promise.all([
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
      db.from("ncaa_transfer_history").select("*").eq("player_id",id).order("is_current",{ascending:false}).order("verified_at",{ascending:false}).limit(30),
      db.from("career_state").select("career_date,managed_player_id").eq("id","demo").maybeSingle(),
      db.from("historical_legend_stats").select("*").eq("player_id",id).maybeSingle(),
      db.from("historical_season_summary").select("*").eq("player_id",id).order("season",{ascending:false}).limit(80),
      db.from("junior_display_pool").select("*").eq("player_id",id).maybeSingle()
    ]);
    const err=p.error||sp.error||titles.error||hist.error||short.error||matches.error||careerStats.error||finals.error||juniorEntries.error||tournamentHistory.error||ncaa.error||ncaaCareer.error||ncaaTransfers.error||careerDate.error||legend.error||historicalSeasons.error||juniorDisplay.error;
    if(err) return h({error:err.message},500);
    const referenceDate=String(careerDate.data?.career_date||AGE_REFERENCE_DATE).slice(0,10);
    const referenceYear=Number(referenceDate.slice(0,4))||2025;
    const dateOk=(v:any)=>!v||String(v).slice(0,10)<=referenceDate;
    const visibleTitles=(titles.data??[]).filter((x:any)=>dateOk(x.title_date));
    const visibleHistory=(hist.data??[]).filter((x:any)=>dateOk(x.snapshot_date));
    const visibleMatches=(matches.data??[]).filter((x:any)=>dateOk(x?.tournament_runs?.tournaments?.start_date));
    const visibleFinals=(finals.data??[]).filter((x:any)=>dateOk(x.final_date));
    const visibleJuniorEntries=(juniorEntries.data??[]).filter((x:any)=>dateOk(x.snapshot_date)&&dateOk(x?.tournaments?.start_date));
    const visibleTournamentHistoryAll=(tournamentHistory.data??[]).filter((x:any)=>dateOk(x.tournament_date));
    const rawSinglesTournamentHistory=visibleTournamentHistoryAll.filter((x:any)=>String(x.event_type||"singles")!=="doubles");
    const legacyRoundRows=rawSinglesTournamentHistory.filter((x:any)=>/^R(?:16|32|64|128)$/.test(String(x.result_code||"")));
    const legacyRoundKeys=[...new Set(legacyRoundRows.map((x:any)=>String(x.season||"")+"|"+String(x.tournament_id||"")).filter(Boolean))];
    const historicalRoundFormats=legacyRoundKeys.length
      ?await db.from("historical_tournament_round_formats").select("event_key,first_round_code").in("event_key",legacyRoundKeys)
      :{data:[],error:null};
    if(historicalRoundFormats.error)return h({error:historicalRoundFormats.error.message},500);
    const historicalRoundMap=new Map((historicalRoundFormats.data??[]).map((x:any)=>[String(x.event_key),Number(x.first_round_code||0)]));
    const canonicalHistoryRound=(x:any)=>{
      const code=String(x.result_code||"");
      const match=code.match(/^R(16|32|64|128)$/);
      if(!match)return x;
      const bracketRound=Number(match[1]);
      const firstRound=historicalRoundMap.get(String(x.season||"")+"|"+String(x.tournament_id||""))||0;
      if(!firstRound||bracketRound>firstRound)return x;
      const ordinal=Math.round(Math.log2(firstRound)-Math.log2(bracketRound)+1);
      if(ordinal<1||ordinal>7)return x;
      return {...x,result_code:"R"+ordinal,result_label:ordinal===1?"1er tour":ordinal+"e tour",legacy_result_code:code};
    };
    const visibleTournamentHistory=rawSinglesTournamentHistory.map(canonicalHistoryRound);
    const doublesHistorySeen=new Set<string>();
    const visibleDoublesTournamentHistory=visibleTournamentHistoryAll
      .filter((x:any)=>String(x.event_type||"")==="doubles")
      .sort((a:any,b:any)=>Number(Boolean(b.last_opponent))-Number(Boolean(a.last_opponent)))
      .filter((x:any)=>{
        const canonicalTournament=String(x.tournament_id||"").replace(/^D-/,"");
        const key=String(x.season||"")+"|"+canonicalTournament;
        if(doublesHistorySeen.has(key))return false;
        doublesHistorySeen.add(key);
        return true;
      })
      .sort((a:any,b:any)=>String(b.tournament_date||"").localeCompare(String(a.tournament_date||"")));
    const visibleNcaa=(ncaa.data??[]).filter((x:any)=>dateOk(x.snapshot_date));
    const visibleNcaaTransfers=(ncaaTransfers.data??[]).filter((x:any)=>dateOk(x.verified_at));
    const visibleHistoricalSeasons=(historicalSeasons.data??[]).filter((x:any)=>Number(x.season||0)<=referenceYear);
    let player:any=p.data;
    if(player&&Array.isArray(player.player_attributes)) player.player_attributes=player.player_attributes[0]??null;
    let doublesTeams:any={data:[],error:null};
    if(player?.name){
      const escapedName=String(player.name).replace(/[,%()]/g," ").trim();
      doublesTeams=await db.from("doubles_race_teams").select("*").or(`player_one.ilike.%${escapedName}%,player_two.ilike.%${escapedName}%`).lte("snapshot_date",referenceDate).order("snapshot_date",{ascending:false}).order("rank",{ascending:true}).limit(20);
    }
    let raceCards:any={junior:null,doubles:null,juniorDoubles:null};
    const jr=await db.rpc("junior_race_for_date",{p_date:referenceDate})
      .eq("id",id).limit(1).maybeSingle();
    if(!jr.error&&jr.data)raceCards.junior={
      rank:jr.data.junior_race_ranking,points:jr.data.junior_race_points,
      status:jr.data.finals_status,snapshot_date:jr.data.junior_race_snapshot_date,
      finals:"ITF World Tennis Tour Junior Finals",source:jr.data.source
    };
    const dr=await db.rpc("doubles_race_for_date",{p_date:referenceDate})
      .or(`player_one_id.eq.${id},player_two_id.eq.${id}`)
      .order("doubles_race_ranking",{ascending:true}).limit(1).maybeSingle();
    if(!dr.error&&dr.data)raceCards.doubles={
      rank:dr.data.doubles_race_ranking,points:dr.data.doubles_race_points,status:dr.data.finals_status,
      snapshot_date:dr.data.doubles_race_snapshot_date,team:dr.data.name,
      finals:"Nitto ATP Finals",source:dr.data.source
    };
    const jdr=await db.rpc("junior_doubles_race_for_date",{p_date:referenceDate})
      .or(`player_one_id.eq.${id},player_two_id.eq.${id}`)
      .order("junior_doubles_race_ranking",{ascending:true}).limit(1).maybeSingle();
    if(!jdr.error&&jdr.data)raceCards.juniorDoubles={
      rank:jdr.data.junior_doubles_race_ranking,points:jdr.data.junior_doubles_race_points,status:jdr.data.finals_status,
      snapshot_date:jdr.data.junior_doubles_race_snapshot_date,team:jdr.data.name,
      finals:"Court Boss Junior Doubles Finals",source:jdr.data.source
    };

    if(player){
      const gameDate=referenceDate;
      player.age=ageAt(player.birth_date,gameDate,player.age,player.age_snapshot_date);
      player=await resolvePlayerFacts(player,gameDate);
      player.age=ageAt(player.birth_date,AGE_REFERENCE_DATE,player.age,player.age_snapshot_date);
      player.age_reference_date=AGE_REFERENCE_DATE;

      if(juniorDisplay.data){
        player.junior_ranking=juniorDisplay.data.display_rank;
        player.junior_game_ranking=juniorDisplay.data.display_rank;
        player.junior_rank_type=juniorDisplay.data.rank_type;
        player.junior_official_ranking=juniorDisplay.data.official_rank;
        player.junior_rank_source=juniorDisplay.data.source_label;
        player.junior_rank_source_url=juniorDisplay.data.source_url;
        player.junior_rank_snapshot_date=juniorDisplay.data.snapshot_date;
      }

      const ncaaRows=visibleNcaa;
      const bestNcaa=ncaaRows.find((x:any)=>x.status==="Active"&&(x.ita_rank_official!=null||x.projected_rank!=null||x.ita_rank!=null))
        ??ncaaRows.find((x:any)=>x.ita_rank_official!=null||x.projected_rank!=null||x.ita_rank!=null)
        ??ncaaRows[0];
      if(bestNcaa){
        const officialNcaaRank=bestNcaa.ita_rank_official!=null?Number(bestNcaa.ita_rank_official):null;
        const projectedNcaaRank=bestNcaa.projected_rank!=null?Number(bestNcaa.projected_rank):null;
        player.ncaa_rank=officialNcaaRank??projectedNcaaRank??bestNcaa.ita_rank??player.ncaa_rank;
        player.ncaa_official_rank=officialNcaaRank;
        player.ncaa_projected_rank=projectedNcaaRank;
        player.ncaa_rank_type=officialNcaaRank!=null?"official":projectedNcaaRank!=null?"simulated_depth":"verified_other";
        player.ncaa_rank_source=bestNcaa.source_label||bestNcaa.source_url||player.ncaa_source||null;
        player.ncaa_rank_source_url=bestNcaa.source_url||null;
        player.ncaa_school=bestNcaa.school??player.ncaa_school;
        player.ncaa_division=bestNcaa.division??player.ncaa_division;
        player.ncaa_status=bestNcaa.status??player.ncaa_status;
        player.ncaa_snapshot_date=bestNcaa.snapshot_date??player.ncaa_snapshot_date;
      }

      if(player.ranking_snapshot_date&&String(player.ranking_snapshot_date)>referenceDate){
        player.ranking=null;player.source_ranking=null;player.ranking_current=false;
      }
      if(player.doubles_snapshot_date&&String(player.doubles_snapshot_date)>referenceDate){
        player.doubles_ranking=null;player.doubles_points=null;player.doubles_source=null;
      }
      if(player.ncaa_snapshot_date&&String(player.ncaa_snapshot_date)>referenceDate&&!bestNcaa){
        player.ncaa_rank=null;player.ncaa_school=null;player.ncaa_status=null;player.ncaa_current=false;
      }
      player=await resolvePlayerPhoto(player);
    }
    const [staffLinks,staffHistory,staffBonds,relA,relB,agencyRepresentation,agencyHistory,focusHistory,primaryDoublesCommitment,doublesPartnerHistory]=await Promise.all([
      db.from("player_staff_assignments")
        .select("id,role,start_date,end_date,active,verified,affinity,trust,role_fit,satisfaction,team_chemistry,source_url,source_label,snapshot_date,notes,weekly_salary,contract_end,ended_reason,staff:staff_profiles(*)")
        .eq("player_id",id).eq("active",true).lte("snapshot_date",referenceDate)
        .order("verified",{ascending:false}).order("affinity",{ascending:false}).limit(20),
      db.from("player_staff_assignments")
        .select("id,role,start_date,end_date,active,verified,affinity,trust,source_url,source_label,snapshot_date,notes,weekly_salary,contract_end,ended_reason,staff:staff_profiles(*)")
        .eq("player_id",id).eq("active",false).lte("snapshot_date",referenceDate)
        .order("end_date",{ascending:false}).limit(12),
      db.from("staff_player_bonds")
        .select("bond_type,affinity,trust,respect,is_simulated,source_label,formed_date,last_update,staff:staff_profiles!staff_player_bonds_staff_profile_id_fkey(id,name,nationality,primary_role,specialty,reputation,former_player_status,former_player_id,market_status)")
        .eq("player_id",id).eq("active",true).lte("last_update",referenceDate)
        .order("affinity",{ascending:false}).limit(20),
      db.from("player_relationships")
        .select("id,relation_type,affinity,trust,respect,closeness,is_simulated,source_label,source_url,formed_date,last_update,other:players!player_relationships_player_b_id_fkey(id,name,country,ranking,doubles_ranking,photo_url)")
        .eq("player_a_id",id).eq("active",true).lte("last_update",referenceDate)
        .order("affinity",{ascending:false}).limit(12),
      db.from("player_relationships")
        .select("id,relation_type,affinity,trust,respect,closeness,is_simulated,source_label,source_url,formed_date,last_update,other:players!player_relationships_player_a_id_fkey(id,name,country,ranking,doubles_ranking,photo_url)")
        .eq("player_b_id",id).eq("active",true).lte("last_update",referenceDate)
        .order("affinity",{ascending:false}).limit(12),
      db.from("player_agency_representation")
        .select("start_date,end_date,commission_pct,active,trust,agency:staff_agencies(*),agent:staff_profiles!player_agency_representation_agent_staff_id_fkey(id,name,nationality,primary_role,reputation,negotiation_rating,former_player_status,former_player_id)")
        .eq("player_id",id).eq("active",true).lte("start_date",referenceDate).maybeSingle(),
      db.from("player_agency_history")
        .select("start_date,end_date,commission_pct,trust_start,trust_end,ended_reason,agency:staff_agencies(*),agent:staff_profiles!player_agency_history_agent_staff_id_fkey(id,name,nationality,primary_role,reputation)")
        .eq("player_id",id).lte("start_date",referenceDate)
        .order("end_date",{ascending:false}).limit(8),
      db.from("player_career_focus_history")
        .select("changed_at,from_focus,to_focus,reason,source")
        .eq("player_id",id).lte("changed_at",referenceDate)
        .order("changed_at",{ascending:false}).limit(20),
      db.from("player_doubles_commitments")
        .select("season,started_at,last_review_date,commitment,affinity,switches,reason,source_label,active,partner:players!player_doubles_commitments_primary_partner_id_fkey(id,name,country,doubles_ranking,career_focus,photo_url)")
        .eq("player_id",id).eq("active",true).lte("started_at",referenceDate).maybeSingle(),
      db.from("player_doubles_partner_history")
        .select("start_date,end_date,season,affinity_start,affinity_end,reason,source_label,partner:players!player_doubles_partner_history_partner_id_fkey(id,name,country,doubles_ranking,career_focus,photo_url)")
        .eq("player_id",id).lte("start_date",referenceDate)
        .order("end_date",{ascending:false}).limit(12)
    ]);
    const socialRows=[...(relA.data??[]),...(relB.data??[])]
      .sort((a:any,b:any)=>Number(b.affinity||0)-Number(a.affinity||0))
      .slice(0,12);

    const primaryManagedProfileId=Number(careerDate.data?.managed_player_id||0);
    const managedRosterCheck=id===primaryManagedProfileId
      ?{data:{id:0},error:null} as any
      :await db.from("academy_roster").select("id").eq("player_id",id).eq("status","active").maybeSingle();
    if(managedRosterCheck.error)return h({error:managedRosterCheck.error.message},500);
    const managedProfile=id===primaryManagedProfileId||Boolean(managedRosterCheck.data);

    let managedIdForMatchup=Number(requestedManagedContextId||primaryManagedProfileId||0);
    if(managedIdForMatchup&&managedIdForMatchup!==primaryManagedProfileId){
      const contextRoster=await db.from("academy_roster").select("id").eq("player_id",managedIdForMatchup).eq("status","active").maybeSingle();
      if(contextRoster.error)return h({error:contextRoster.error.message},500);
      if(!contextRoster.data)managedIdForMatchup=primaryManagedProfileId;
    }

    const [developmentProfile,developmentHistory,developmentTraitHistory,scoutingReport,roleSuitability,attributeCeilings,attributeTrend,hiddenTraitHistory,advancedMetrics,eloRating,dynamicRatings,styleHistory,tacticalProfile,tacticalTraits,seasonPlan,trainingLoad,surfacePreference,contextProfile,psychologyState,h2hWithManaged,hardPreview,clayPreview,grassPreview]=await Promise.all([
      db.from("player_development_profiles").select("*").eq("player_id",id).maybeSingle(),
      db.from("player_development_history").select("*").eq("player_id",id).lte("event_date",referenceDate).order("event_date",{ascending:false}).limit(30),
      managedProfile
        ?db.from("player_development_trait_history").select("*").eq("player_id",id).lte("event_date",referenceDate).order("event_date",{ascending:false}).order("id",{ascending:false}).limit(60)
        :Promise.resolve({data:[],error:null}),
      db.from("scouting_reports").select("*").eq("player_id",id).lte("report_date",referenceDate).order("report_date",{ascending:false}).order("confidence",{ascending:false}).limit(1).maybeSingle(),
      db.from("player_role_suitability").select("*").eq("player_id",id).maybeSingle(),
      db.from("player_attribute_ceilings").select("ceilings,ability_snapshot,potential_snapshot,development_type,last_review_date").eq("player_id",id).maybeSingle(),
      db.from("player_attribute_trends").select("*").eq("player_id",id).maybeSingle(),
      managedProfile
        ?db.from("player_hidden_trait_history").select("*").eq("player_id",id).lte("event_date",referenceDate).order("event_date",{ascending:false}).limit(30)
        :Promise.resolve({data:[],error:null}),
      db.from("player_advanced_metrics").select("*").eq("player_id",id).maybeSingle(),
      db.from("player_elo_ratings").select("*").eq("player_id",id).maybeSingle(),
      db.from("player_dynamic_ratings").select("*").eq("player_id",id).maybeSingle(),
      db.from("player_style_history").select("*").eq("player_id",id).lte("changed_at",referenceDate).order("changed_at",{ascending:false}).limit(20),
      db.from("player_tactical_preferences").select("*").eq("player_id",id).maybeSingle(),
      db.from("player_tactical_traits").select("trait_code,trait_name,intensity,source_label").eq("player_id",id).eq("active",true).order("intensity",{ascending:false}).limit(8),
      db.from("player_season_plans").select("*").eq("player_id",id).lte("season",Number(referenceDate.slice(0,4))+1).order("season",{ascending:false}).limit(1).maybeSingle(),
      db.from("player_training_load_profiles").select("*").eq("player_id",id).maybeSingle(),
      db.from("player_surface_preferences").select("*").eq("player_id",id).maybeSingle(),
      db.from("player_context_traits").select("*").eq("player_id",id).maybeSingle(),
      db.from("player_psychology_state").select("*").eq("player_id",id).maybeSingle(),
      managedIdForMatchup&&managedIdForMatchup!==id
        ?db.from("player_h2h_records").select("*").eq("player_a_id",Math.min(id,managedIdForMatchup)).eq("player_b_id",Math.max(id,managedIdForMatchup)).maybeSingle()
        :Promise.resolve({data:null,error:null}),
      managedIdForMatchup&&managedIdForMatchup!==id
        ?db.rpc("player_matchup_probability_v4",{p_a:id,p_b:managedIdForMatchup,p_surface:"Hard",p_date:referenceDate,p_court_speed:1.0,p_best_of:3})
        :Promise.resolve({data:null,error:null}),
      managedIdForMatchup&&managedIdForMatchup!==id
        ?db.rpc("player_matchup_probability_v4",{p_a:id,p_b:managedIdForMatchup,p_surface:"Clay",p_date:referenceDate,p_court_speed:.68,p_best_of:3})
        :Promise.resolve({data:null,error:null}),
      managedIdForMatchup&&managedIdForMatchup!==id
        ?db.rpc("player_matchup_probability_v4",{p_a:id,p_b:managedIdForMatchup,p_surface:"Grass",p_date:referenceDate,p_court_speed:1.15,p_best_of:3})
        :Promise.resolve({data:null,error:null})
    ]);

    const bySeason=new Map<number,{season:number,singles_eur:number,doubles_eur:number,total_eur:number,events:number}>();
    const addFinancial=(dateValue:any,singles:number,doubles:number)=>{
      const season=Number(String(dateValue||referenceDate).slice(0,4))||referenceYear;
      const current=bySeason.get(season)||{season,singles_eur:0,doubles_eur:0,total_eur:0,events:0};
      current.singles_eur=Math.round((current.singles_eur+Number(singles||0))*100)/100;
      current.doubles_eur=Math.round((current.doubles_eur+Number(doubles||0))*100)/100;
      current.total_eur=Math.round((current.singles_eur+current.doubles_eur)*100)/100;
      current.events+=1;
      bySeason.set(season,current);
    };
    let singlesPrizeEur=0,doublesPrizeEur=0,financialEvents=0,estimatedPrizeEvents=0;

    if(managedProfile){
      const [managedSingles,managedDoubles]=await Promise.all([
        db.from("tournament_runs")
          .select("user_prize_eur,user_prize,played_at,tournaments(start_date,end_date,prize_currency,prize_breakdown_is_estimate)")
          .eq("managed_player_id",id).eq("status","completed").order("played_at",{ascending:true}).limit(1000),
        db.from("doubles_runs")
          .select("user_prize_eur,user_prize,played_at,tournaments(start_date,end_date,prize_currency,prize_breakdown_is_estimate)")
          .eq("managed_player_id",id).eq("status","completed").order("played_at",{ascending:true}).limit(1000)
      ]);
      if(!managedSingles.error){
        for(const row of managedSingles.data??[]){
          const tour:any=Array.isArray((row as any).tournaments)?(row as any).tournaments[0]:(row as any).tournaments;
          const dateValue=tour?.end_date||tour?.start_date||(row as any).played_at;
          if(dateValue&&String(dateValue).slice(0,10)>referenceDate)continue;
          const amount=Number((row as any).user_prize_eur??prizeToBaseEur((row as any).user_prize,tour?.prize_currency||"USD"));
          singlesPrizeEur+=amount;financialEvents++;if(tour?.prize_breakdown_is_estimate)estimatedPrizeEvents++;
          addFinancial(dateValue,amount,0);
        }
      }
      if(!managedDoubles.error){
        for(const row of managedDoubles.data??[]){
          const tour:any=Array.isArray((row as any).tournaments)?(row as any).tournaments[0]:(row as any).tournaments;
          const dateValue=tour?.end_date||tour?.start_date||(row as any).played_at;
          if(dateValue&&String(dateValue).slice(0,10)>referenceDate)continue;
          const amount=Number((row as any).user_prize_eur??prizeToBaseEur((row as any).user_prize,tour?.prize_currency||"USD"));
          doublesPrizeEur+=amount;financialEvents++;if(tour?.prize_breakdown_is_estimate)estimatedPrizeEvents++;
          addFinancial(dateValue,0,amount);
        }
      }
    }else{
      const [worldSingles,pairRows,worldQualifying]=await Promise.all([
        db.from("world_tournament_entries")
          .select("result_code,simulated_on,prize_awarded,prize_currency,prize_is_estimate,tournaments(id,name,start_date,end_date,prize_currency,singles_prize_by_result,prize_breakdown_is_estimate)")
          .eq("player_id",id).lte("simulated_on",referenceDate).order("simulated_on",{ascending:true}).limit(1000),
        db.from("world_doubles_partnerships")
          .select("id").or(`player_a_id.eq.${id},player_b_id.eq.${id}`).limit(500),
        db.from("world_tournament_qualifying_entries")
          .select("result_code,qualified,prize_awarded,prize_currency,prize_is_estimate,simulated_on,tournaments(id,name,start_date,end_date)")
          .eq("player_id",id).eq("qualified",false).lte("simulated_on",referenceDate).order("simulated_on",{ascending:true}).limit(1000)
      ]);
      if(!worldSingles.error){
        for(const row of worldSingles.data??[]){
          const tour:any=Array.isArray((row as any).tournaments)?(row as any).tournaments[0]:(row as any).tournaments;
          if(!tour)continue;
          const snapAmount=Number((row as any).prize_awarded||0);
          const snapCurrency=String((row as any).prize_currency||tour.prize_currency||"USD");
          const payout=snapAmount>0
            ?{amount:snapAmount,estimated:Boolean((row as any).prize_is_estimate)}
            :tournamentRoundPrize(tour,String((row as any).result_code||""),"singles");
          const amount=prizeToBaseEur(payout.amount,snapCurrency);
          singlesPrizeEur+=amount;financialEvents++;if(payout.estimated||tour.prize_breakdown_is_estimate)estimatedPrizeEvents++;
          addFinancial((row as any).simulated_on||tour.end_date||tour.start_date,amount,0);
        }
      }
      if(!worldQualifying.error){
        for(const row of worldQualifying.data??[]){
          const prize=Number((row as any).prize_awarded||0);
          if(prize<=0)continue;
          const tour:any=Array.isArray((row as any).tournaments)?(row as any).tournaments[0]:(row as any).tournaments;
          const currency=String((row as any).prize_currency||"USD");
          const amount=prizeToBaseEur(prize,currency);
          singlesPrizeEur+=amount;financialEvents++;
          if(Boolean((row as any).prize_is_estimate))estimatedPrizeEvents++;
          addFinancial((row as any).simulated_on||tour?.end_date||tour?.start_date,amount,0);
        }
      }
      const pairIds=(pairRows.error?[]:(pairRows.data??[])).map((x:any)=>Number(x.id)).filter(Boolean);
      if(pairIds.length){
        const worldDoubles=await db.from("world_doubles_tournament_entries")
          .select("pair_id,prize_awarded,simulated_on,tournaments(id,name,start_date,end_date,prize_currency,prize_breakdown_is_estimate)")
          .in("pair_id",pairIds).lte("simulated_on",referenceDate).order("simulated_on",{ascending:true}).limit(1000);
        if(!worldDoubles.error){
          for(const row of worldDoubles.data??[]){
            const tour:any=Array.isArray((row as any).tournaments)?(row as any).tournaments[0]:(row as any).tournaments;
            const playerShare=Math.round(Number((row as any).prize_awarded||0)/2*100)/100;
            const amount=prizeToBaseEur(playerShare,tour?.prize_currency||"USD");
            doublesPrizeEur+=amount;financialEvents++;if(tour?.prize_breakdown_is_estimate)estimatedPrizeEvents++;
            addFinancial((row as any).simulated_on||tour?.end_date||tour?.start_date,0,amount);
          }
        }
      }
    }
    singlesPrizeEur=Math.round(singlesPrizeEur*100)/100;
    doublesPrizeEur=Math.round(doublesPrizeEur*100)/100;
    const careerFinancials={
      base_currency:BASE_CURRENCY,
      from_date:AGE_REFERENCE_DATE,
      through_date:referenceDate,
      singles_prize_eur:singlesPrizeEur,
      doubles_prize_eur:doublesPrizeEur,
      total_prize_eur:Math.round((singlesPrizeEur+doublesPrizeEur)*100)/100,
      events:financialEvents,
      estimated_events:estimatedPrizeEvents,
      seasons:[...bySeason.values()].sort((x,y)=>y.season-x.season),
      scope:"Court Boss simulated career only"
    };

    const statisticsDashboard=await db.rpc("player_statistics_dashboard_v2",{p_player_id:id,p_as_of:referenceDate});

    return h({
      player,sponsors:sp.data??[],titles:visibleTitles,history:visibleHistory,shortlist:short.data??null,
      matches:visibleMatches,careerStats:careerStats.data??null,finals:visibleFinals,juniorEntries:visibleJuniorEntries,
      tournamentHistory:visibleTournamentHistory,doublesTournamentHistory:visibleDoublesTournamentHistory,ncaa:visibleNcaa,ncaaCareer:ncaaCareer.data??null,ncaaTransfers:visibleNcaaTransfers,doublesTeams:doublesTeams.data??[],races:raceCards,legend:legend.data??null,historicalSeasons:visibleHistoricalSeasons,
      staff:staffLinks.error?[]:(staffLinks.data??[]),
      staffHistory:staffHistory.error?[]:(staffHistory.data??[]),
      staffBonds:staffBonds.error?[]:(staffBonds.data??[]),
      relationships:socialRows,
      agencyRepresentation:agencyRepresentation.error?null:agencyRepresentation.data,
      agencyHistory:agencyHistory.error?[]:(agencyHistory.data??[]),
      careerFocusHistory:focusHistory.error?[]:(focusHistory.data??[]),
      primaryDoublesCommitment:primaryDoublesCommitment.error?null:primaryDoublesCommitment.data,
      doublesPartnerHistory:doublesPartnerHistory.error?[]:(doublesPartnerHistory.data??[]),
      developmentProfile:developmentProfile.error?null:developmentProfile.data,
      developmentHistory:developmentHistory.error?[]:(developmentHistory.data??[]),
      developmentTraitHistory:developmentTraitHistory.error?[]:(developmentTraitHistory.data??[]),
      scoutingReport:scoutingReport.error?null:scoutingReport.data,
      roleSuitability:(managedProfile||Number(scoutingReport.data?.confidence||0)>=80)&&!roleSuitability.error?roleSuitability.data:null,
      attributeCeilings:managedProfile&&!attributeCeilings.error?attributeCeilings.data:null,
      attributeTrend:(managedProfile||Number(scoutingReport.data?.confidence||0)>=85)&&!attributeTrend.error?attributeTrend.data:null,
      hiddenTraitHistory:managedProfile&&!hiddenTraitHistory.error?(hiddenTraitHistory.data??[]):[],
      advancedMetrics:advancedMetrics.error?null:advancedMetrics.data,
      careerFinancials,
      statisticsDashboard:statisticsDashboard.error?null:statisticsDashboard.data,
      eloRating:eloRating.error?null:eloRating.data,
      dynamicRatings:dynamicRatings.error?null:dynamicRatings.data,
      styleHistory:styleHistory.error?[]:(styleHistory.data??[]),
      tacticalProfile:tacticalProfile.error?null:tacticalProfile.data,
      tacticalTraits:tacticalTraits.error?[]:(tacticalTraits.data??[]),
      seasonPlan:seasonPlan.error?null:seasonPlan.data,
      trainingLoad:trainingLoad.error?null:(
        managedIdForMatchup===id
          ?null
          :Number(scoutingReport.data?.confidence||0)>=75
            ?trainingLoad.data
            :trainingLoad.data?{phase:trainingLoad.data.phase,as_of_date:trainingLoad.data.as_of_date}:null
      ),
      surfacePreference:surfacePreference.error?null:surfacePreference.data,
      contextProfile:contextProfile.error?null:contextProfile.data,
      psychologyState:psychologyState.error?null:(
        managedIdForMatchup===id||Number(scoutingReport.data?.confidence||0)>=82
          ?psychologyState.data
          :psychologyState.data
            ?{
                status_label:psychologyState.data.status_label,
                win_streak:psychologyState.data.win_streak,
                loss_streak:psychologyState.data.loss_streak,
                last_result:psychologyState.data.last_result,
                last_match_date:psychologyState.data.last_match_date
              }
            :null
      ),
      h2hWithManaged:h2hWithManaged.error?null:h2hWithManaged.data,
      matchupPreviews:{
        hard:hardPreview.error?null:hardPreview.data,
        clay:clayPreview.error?null:clayPreview.data,
        grass:grassPreview.error?null:grassPreview.data
      }
    });
  }

  if(path.endsWith("/api/tournament-image")&&req.method==="GET"){
    const id=n(u.searchParams.get("id"),0,1,99999999);
    const q=await db.from("tournaments").select("*").eq("id",id).eq("is_active",true).maybeSingle();
    if(q.error)return new Response("",{status:500,headers:cors});
    if(!q.data)return new Response("",{status:404,headers:cors});
    const t=await resolveTournamentImage(q.data);
    if(!t?.image_url)return new Response("",{status:404,headers:{...cors,"Cache-Control":"public, max-age=3600"}});
    const proxy=u.searchParams.get("proxy")==="1";
    if(proxy){
      try{
        const headers:Record<string,string>={
          "User-Agent":"CourtBoss/1.0 (+tournament-image-proxy)",
          "Accept":"image/avif,image/webp,image/apng,image/*,*/*;q=0.8"
        };
        const referer=String(t.image_source_url||t.source_url||"").trim();
        if(/^https?:\/\//i.test(referer))headers["Referer"]=referer;
        const image=await fetch(String(t.image_url),{
          headers,redirect:"follow",signal:AbortSignal.timeout(8000)
        });
        const contentType=String(image.headers.get("content-type")||"");
        if(image.ok&&/^image\//i.test(contentType)){
          return new Response(image.body,{
            status:200,
            headers:{
              ...cors,
              "Content-Type":contentType,
              "Cache-Control":"public, max-age=86400, stale-while-revalidate=604800"
            }
          });
        }
      }catch{}
    }
    return new Response(null,{status:302,headers:{...cors,"Location":String(t.image_url),"Cache-Control":"public, max-age=86400"}});
  }


  if(path.endsWith("/api/competitions")&&req.method==="GET"){
    const q=(u.searchParams.get("q")??"").trim().slice(0,80);
    const circuit=(u.searchParams.get("circuit")??"Tous").trim().slice(0,30);
    const category=(u.searchParams.get("category")??"Toutes").trim().slice(0,40);
    const surface=(u.searchParams.get("surface")??"Toutes").trim().slice(0,40);
    const country=(u.searchParams.get("country")??"").trim().slice(0,12);
    const source=(u.searchParams.get("source")??"Tous").trim().slice(0,20);
    const prestige=(u.searchParams.get("prestige")??"Tous").trim().slice(0,20);
    const historyFilter=(u.searchParams.get("history")??"Tous").trim().slice(0,24);
    const holderFilter=(u.searchParams.get("holder")??"Tous").trim().slice(0,24);
    const offset=n(u.searchParams.get("offset"),0,0,10000),limit=n(u.searchParams.get("limit"),100,1,200);

    let tq=db.from("tournaments").select("*").eq("is_active",true).gte("start_date","2025-12-01").order("start_date",{ascending:true}).limit(5000);
    if(circuit!=="Tous")tq=tq.eq("circuit",circuit);
    if(category!=="Toutes")tq=tq.eq("category",category);
    if(country)tq=tq.eq("country",country);
    if(source==="Officiel")tq=tq.eq("is_verified",true);
    if(source==="Fictif")tq=tq.eq("is_verified",false).in("circuit",["Challenger","ITF"]);
    if(q)tq=tq.ilike("name",`%${q}%`);
    const {data,error}=await tq;
    if(error)return h({error:error.message},500);

    const byKey=new Map<string,any>();
    for(const t of data??[]){
      const surf=String(t.surface||"");
      const label=surf==="Dur"?(t.indoor?"Dur intérieur":"Dur extérieur"):surf;
      if(surface!=="Toutes"&&label!==surface)continue;
      const key=String(t.competition_key||("id:"+t.id));
      const old=byKey.get(key);
      if(!old||String(t.start_date)<String(old.start_date))byKey.set(key,t);
    }
    let rows=[...byKey.values()];
    const keys=rows.map((x:any)=>x.competition_key).filter(Boolean);
    const groups=[...new Set(rows.map((x:any)=>String(x.history_group||"")).filter(Boolean))];
    const histCounts=new Map<string,number>(),groupCounts=new Map<string,number>(),latestHist=new Map<string,any>(),latestGroupHist=new Map<string,any>();
    for(let i=0;i<keys.length;i+=200){
      const hr=await db.from("competition_history")
        .select("competition_key,season,winner_name,winner_player_id,runner_up_name,event_date")
        .in("competition_key",keys.slice(i,i+200))
        .order("season",{ascending:false});
      if(!hr.error){
        for(const x of hr.data??[]){
          histCounts.set(x.competition_key,(histCounts.get(x.competition_key)||0)+1);
          if(!latestHist.has(x.competition_key))latestHist.set(x.competition_key,x);
        }
      }
    }
    for(let i=0;i<groups.length;i+=200){
      const hr=await db.from("tournament_edition_history")
        .select("history_group,season,winner_name,winner_player_id,runner_up_name,final_date")
        .in("history_group",groups.slice(i,i+200))
        .eq("event_type","singles")
        .order("season",{ascending:false});
      if(!hr.error){
        for(const x of hr.data??[]){
          groupCounts.set(x.history_group,(groupCounts.get(x.history_group)||0)+1);
          if(!latestGroupHist.has(x.history_group))latestGroupHist.set(x.history_group,x);
        }
      }
    }
    rows=rows.map((t:any)=>{
      const keyCount=histCounts.get(t.competition_key)||0;
      const groupCount=groupCounts.get(t.history_group)||0;
      return {
        ...t,
        history_count:Math.max(keyCount,groupCount),
        latest_history:groupCount>=keyCount
          ?(latestGroupHist.get(t.history_group)||latestHist.get(t.competition_key)||null)
          :(latestHist.get(t.competition_key)||latestGroupHist.get(t.history_group)||null)
      };
    });
    if(prestige==="5 étoiles")rows=rows.filter((x:any)=>Number(x.prestige||0)>=90);
    else if(prestige==="4+ étoiles")rows=rows.filter((x:any)=>Number(x.prestige||0)>=70);
    else if(prestige==="3+ étoiles")rows=rows.filter((x:any)=>Number(x.prestige||0)>=50);
    if(historyFilter==="Avec historique")rows=rows.filter((x:any)=>Number(x.history_count||0)>0);
    if(historyFilter==="Sans historique")rows=rows.filter((x:any)=>Number(x.history_count||0)===0);
    if(holderFilter==="Avec tenant")rows=rows.filter((x:any)=>!!x.defending_champion_name||!!x.latest_history?.winner_name);
    if(holderFilter==="Sans tenant")rows=rows.filter((x:any)=>!x.defending_champion_name&&!x.latest_history?.winner_name);
    rows=rows.sort((a:any,b:any)=>Number(b.prestige||0)-Number(a.prestige||0)||String(a.start_date).localeCompare(String(b.start_date))||String(a.name).localeCompare(String(b.name)));
    return h({offset,limit,count:rows.length,rows:rows.slice(offset,offset+limit)});
  }

  if(path.endsWith("/api/competition")&&req.method==="GET"){
    const id=n(u.searchParams.get("id"),0,1,99999999);
    const tr=await db.from("tournaments").select("*").eq("id",id).maybeSingle();
    if(tr.error)return h({error:tr.error.message},500);
    if(!tr.data)return h({error:"competition not found"},404);
    const t:any=await resolveTournamentImage(tr.data),key=String(tr.data.competition_key||"");
    let history:any[]=[];
    if(key){
      const x=await db.from("competition_history").select("*").eq("competition_key",key).order("season",{ascending:false}).limit(250);
      if(!x.error)history=x.data??[];
    }
    if(!history.length&&t.city){
      const x=await db.from("competition_history").select("*").ilike("tournament_name",`%${String(t.city)}%`).order("season",{ascending:false}).limit(250);
      if(!x.error){
        history=(x.data??[]).filter((r:any)=>{
          if(t.category==="Grand Chelem")return r.level==="Grand Chelem";
          if(t.circuit==="Challenger")return /Challenger|ATP Tour/.test(String(r.level||""));
          return true;
        });
      }
    }
    if(t.history_group){
      const full=await db.from("tournament_edition_history")
        .select("season,final_date,tournament_name,level,surface,winner_player_id,winner_name,runner_up_player_id,runner_up_name,score,source_url,source_label")
        .eq("history_group",String(t.history_group))
        .eq("event_type","singles")
        .order("season",{ascending:false})
        .limit(250);
      if(!full.error&&(full.data??[]).length>history.length){
        history=(full.data??[]).map((x:any)=>({
          ...x,
          event_date:x.final_date,
          competition_key:key,
          event_type:"singles"
        }));
      }
    }

    const editions=key
      ?await db.from("tournaments").select("id,name,start_date,end_date,city,country,surface,indoor,category,circuit,is_verified,defending_champion_name,image_url").eq("competition_key",key).order("start_date",{ascending:false}).limit(20)
      :{data:[t],error:null};

    const rec=new Map<string,{name:string,player_id:number|null,wins:number,finals:number}>();
    for(const r of history){
      const wk=String(r.winner_player_id||r.winner_name);
      const w=rec.get(wk)||{name:r.winner_name,player_id:r.winner_player_id||null,wins:0,finals:0};
      w.wins++;w.finals++;rec.set(wk,w);
      const rk=String(r.runner_up_player_id||r.runner_up_name);
      const ru=rec.get(rk)||{name:r.runner_up_name,player_id:r.runner_up_player_id||null,wins:0,finals:0};
      ru.finals++;rec.set(rk,ru);
    }
    const records=[...rec.values()].sort((a,b)=>b.wins-a.wins||b.finals-a.finals||a.name.localeCompare(b.name)).slice(0,25);
    return h({
      tournament:t,history,editions:editions.data??[],records,
      historyStart:history.length?Math.min(...history.map((x:any)=>Number(x.season)||9999)):null,
      historyEnd:history.length?Math.max(...history.map((x:any)=>Number(x.season)||0)):null
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
    const requestedManagedPlayerId=n(u.searchParams.get("player_id"),0,0,99999999);
    let query=db.from("tournaments").select("*",{count:"exact"}).eq("is_active",true);
    if(circuit&&circuit!=="Tous") query=query.eq("circuit",circuit);
    if(category&&category!=="Toutes") query=query.eq("category",category);
    if(source==="Officiel") query=query.eq("is_verified",true);
    if(source==="Simulation") query=query.eq("is_verified",false);
    if(source==="Fictif") query=query.eq("is_verified",false);
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

    // Surface the managed player's frozen acceptance state directly in the
    // tournament calendar so the list view shows real DA / ALT / Q status,
    // not only a projected cut until the detail sheet is opened.
    let rows:any[]=(data??[]);
    const tournamentIds=rows.map((x:any)=>Number(x.id||0)).filter(Boolean);
    if(tournamentIds.length){
      const managed=await db.from("career_state").select("managed_player_id").eq("id","demo").maybeSingle();
      if(managed.error)return h({error:managed.error.message},500);
      const primaryManagedId=Number(managed.data?.managed_player_id||0);
      const managedId=Number(requestedManagedPlayerId||primaryManagedId||0);
      if(managedId&&managedId!==primaryManagedId){
        const rosterCheck=await db.from("academy_roster").select("id").eq("player_id",managedId).eq("status","active").maybeSingle();
        if(rosterCheck.error)return h({error:rosterCheck.error.message},500);
        if(!rosterCheck.data)return h({error:"Ce joueur ne fait pas partie du groupe géré."},403);
      }
      if(managedId){
        const [mainAcceptance,qAcceptance]=await Promise.all([
          db.from("world_tournament_acceptance_entries")
            .select("tournament_id,status,acceptance_order,effective_rank,entry_method,snapshot_date,promoted_on,withdrawn_on,withdrawal_phase,withdrawal_reason")
            .eq("player_id",managedId).in("tournament_id",tournamentIds),
          db.from("world_qualifying_acceptance_entries")
            .select("tournament_id,status,acceptance_order,effective_rank,entry_method,snapshot_date,promoted_on,withdrawn_on,withdrawal_phase,withdrawal_reason")
            .eq("player_id",managedId).in("tournament_id",tournamentIds)
        ]);
        if(mainAcceptance.error||qAcceptance.error)return h({error:(mainAcceptance.error||qAcceptance.error)?.message},500);
        const mainMap=new Map((mainAcceptance.data??[]).map((x:any)=>[Number(x.tournament_id),x]));
        const qMap=new Map((qAcceptance.data??[]).map((x:any)=>[Number(x.tournament_id),x]));
        rows=rows.map((t:any)=>({
          ...t,
          managed_acceptance_player_id:managedId,
          managed_acceptance_main:mainMap.get(Number(t.id))??null,
          managed_acceptance_qualifying:qMap.get(Number(t.id))??null
        }));
      }
    }

    const year=Number((month||from||"2025").slice(0,4))||2025;
    let tbcRows:any[]=[];
    if(source!=="Simulation"&&source!=="Fictif"){
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
    return h({offset,limit,count:count??0,rows,tbc:tbcRows});
  }


  if(path.endsWith("/api/tournament-entry-status")&&req.method==="GET"){
    const id=n(u.searchParams.get("id"),0,1,99999999);
    const requestedPlayerId=n(u.searchParams.get("player_id"),0,0,99999999);
    const [t,career]=await Promise.all([
      db.from("tournaments").select("*").eq("id",id).eq("is_active",true).maybeSingle(),
      db.from("career_state").select("managed_player_id").eq("id","demo").maybeSingle()
    ]);
    if(t.error||career.error)return h({error:(t.error||career.error)?.message},500);
    if(!t.data)return h({error:"Tournoi introuvable"},404);
    const primaryId=Number(career.data?.managed_player_id||0);
    const playerId=Number(requestedPlayerId||primaryId||0);
    if(!playerId)return h({error:"Joueur managé introuvable"},404);
    if(playerId!==primaryId){
      const roster=await db.from("academy_roster").select("id").eq("player_id",playerId).eq("status","active").maybeSingle();
      if(roster.error)return h({error:roster.error.message},500);
      if(!roster.data)return h({error:"Ce joueur ne fait pas partie du groupe géré."},403);
    }
    const wc=await db.from("wildcard_requests").select("status").eq("tournament_id",id).eq("player_id",playerId).maybeSingle();
    if(wc.error)return h({error:wc.error.message},500);
    try{
      const entryRules=await managedTournamentEntryRules(t.data,playerId);
      const pathways=await managedTournamentPathwayBundle(id,playerId);
      return h({
        tournament:t.data,
        player_id:playerId,
        primary_player_id:primaryId,
        entry_rules:entryRules,
        entry:entryRules?.persisted_entry??null,
        wildcard_status:wc.data?.status||null,
        pathway_status:pathways.pathway,
        special_exempt_status:pathways.special_exempt,
        performance_bye_status:pathways.performance_bye
      })
    }catch(e){return h({error:String((e as any)?.message||e)},500)}
  }

  if(path.endsWith("/api/tournament-entry")&&req.method==="POST"){
    let body:any;try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const tid=n(body?.tournament_id,0,1,99999999);
    const action=String(body?.action||"enter");
    const requestedMethod=String(body?.entry_method||"alternate");
    const legacy=Boolean(body?.legacy);
    const allowed=new Set([
      "direct","qualifying","alternate","protected","protected_qualifying","wildcard",
      "late_entry","special_exempt","junior_reserved",
      "nextgen_accelerator","nextgen_accelerator_qualifying",
      "junior_accelerator","junior_accelerator_qualifying",
      "college_accelerator","college_accelerator_qualifying"
    ]);
    if(!allowed.has(requestedMethod))return h({error:"Méthode d’entrée invalide."},400);

    const [tour,career]=await Promise.all([
      db.from("tournaments").select("*").eq("id",tid).eq("is_active",true).maybeSingle(),
      db.from("career_state").select("managed_player_id,career_date,career_focus").eq("id","demo").maybeSingle()
    ]);
    if(tour.error||career.error)return h({error:(tour.error||career.error)?.message},500);
    if(!tour.data||!career.data?.managed_player_id)return h({error:"Tournoi ou joueur managé introuvable."},404);
    const primaryId=Number(career.data.managed_player_id);
    const playerId=n(body?.player_id,primaryId,1,99999999);
    const gameDate=String(career.data.career_date||AGE_REFERENCE_DATE);
    let playerFocus=String(career.data.career_focus||"mixed");
    if(playerId!==primaryId){
      const [roster,player]=await Promise.all([
        db.from("academy_roster").select("id").eq("player_id",playerId).eq("status","active").maybeSingle(),
        db.from("players").select("id,career_focus").eq("id",playerId).maybeSingle()
      ]);
      if(roster.error||player.error)return h({error:(roster.error||player.error)?.message},500);
      if(!roster.data||!player.data)return h({error:"Ce joueur ne fait pas partie du groupe géré."},403);
      playerFocus=String(player.data.career_focus||"mixed");
    }
    if(playerFocus==="doubles_only")return h({error:"Orientation Double exclusivement : inscription simple désactivée."},409);

    if(action==="withdraw"){
      const upd=await db.from("entries").update({
        status:"withdrawn",withdrawn_on:gameDate,updated_at:new Date().toISOString()
      }).eq("tournament_id",tid).eq("player_id",playerId).select("*").maybeSingle();
      if(upd.error)return h({error:upd.error.message},500);

      const qStart=String(tour.data.qualifying_start_date||tour.data.main_draw_start_date||tour.data.start_date||gameDate);
      const mainPhase=gameDate<qStart?"pre_q":"post_q";

      const [mainMark,qMark]=await Promise.all([
        db.from("world_tournament_acceptance_entries").update({
          status:"withdrawn",withdrawn_on:gameDate,withdrawal_phase:mainPhase,
          withdrawal_reason:"managed_withdrawal",updated_at:new Date().toISOString()
        }).eq("tournament_id",tid).eq("player_id",playerId)
          .in("status",["accepted","promoted","alternate"]).select("player_id"),
        db.from("world_qualifying_acceptance_entries").update({
          status:"withdrawn",withdrawn_on:gameDate,withdrawal_phase:"pre_q",
          withdrawal_reason:"managed_withdrawal",updated_at:new Date().toISOString()
        }).eq("tournament_id",tid).eq("player_id",playerId)
          .in("status",["accepted","promoted","alternate"]).select("player_id")
      ]);
      if(mainMark.error||qMark.error)return h({error:(mainMark.error||qMark.error)?.message},500);

      const [mainRefresh,qRefresh]=await Promise.all([
        db.rpc("refresh_world_tournament_acceptance_list",{p_tournament_id:tid,p_date:gameDate}),
        db.rpc("refresh_world_qualifying_acceptance_list",{p_tournament_id:tid,p_date:gameDate})
      ]);
      const withdrawnMethod=String(upd.data?.entry_method||"");
      const zeroPointer=withdrawnMethod.includes("qualifying")
        ?{data:{recorded:false,reason:"qualifying_entry"},error:null} as any
        :await db.rpc("record_atp_zero_pointer",{
            p_player_id:playerId,p_tournament_id:tid,p_withdrawal_date:gameDate,p_reason:"managed_withdrawal"
          });
      return h({
        ok:true,action:"withdraw",entry:upd.data??null,
        zero_pointer:zeroPointer.error?{recorded:false,error:zeroPointer.error.message}:zeroPointer.data,
        acceptance_marked_withdrawn:(mainMark.data??[]).length,
        qualifying_marked_withdrawn:(qMark.data??[]).length,
        acceptance_refresh:mainRefresh.error?{skipped:true,error:mainRefresh.error.message}:mainRefresh.data,
        qualifying_refresh:qRefresh.error?{skipped:true,error:qRefresh.error.message}:qRefresh.data
      });
    }
    if(action!=="enter")return h({error:"Action d’inscription invalide."},400);

    const pathwayMethods=new Set([
      "late_entry","special_exempt","junior_reserved",
      "nextgen_accelerator","nextgen_accelerator_qualifying",
      "junior_accelerator","junior_accelerator_qualifying",
      "college_accelerator","college_accelerator_qualifying"
    ]);
    let elig:any={};
    if(pathwayMethods.has(requestedMethod)){
      let pathways:any;
      try{pathways=await managedTournamentPathwayBundle(tid,playerId)}
      catch(e){return h({error:String((e as any)?.message||e)},500)}
      const path:any=pathways.pathway||{};
      if(path?.eligible!==true||String(path?.mode||"")!==requestedMethod){
        if(!legacy)return h({
          error:"Cette passerelle d’entrée n’est pas disponible pour ce tournoi.",
          requested_method:requestedMethod,
          pathway_status:path,
          special_exempt_status:pathways.special_exempt
        },409);
      }
      elig={eligible:true,reason:"managed_pathway",entry_method:requestedMethod,pathway:path};
    }else{
      const eligibility=await db.rpc("player_event_eligibility",{
        p_player_id:playerId,p_tournament_id:tid,p_entry_method:requestedMethod
      });
      if(eligibility.error)return h({error:eligibility.error.message},500);
      elig=eligibility.data||{};
      if(elig.eligible===false&&!legacy)return h({error:String(elig.reason||"Joueur non éligible à cette entrée."),eligibility:elig},409);
    }

    if(requestedMethod==="wildcard"){
      const wc=await db.from("wildcard_requests").select("status").eq("tournament_id",tid).eq("player_id",playerId).maybeSingle();
      if(wc.error)return h({error:wc.error.message},500);
      if(wc.data?.status!=="accepted"&&!legacy)return h({error:"La wild card n’est pas accordée."},409);
    }

    const pathwayQualifying=requestedMethod.endsWith("_qualifying");
    const deadline=String(
      requestedMethod==="special_exempt"
        ?""
        :requestedMethod==="late_entry"
          ?tour.data.late_entry_deadline||""
          :requestedMethod==="qualifying"||requestedMethod==="protected_qualifying"||pathwayQualifying
            ?tour.data.qualifying_entry_deadline||tour.data.qualifying_signin_date||""
            :tour.data.main_entry_deadline||tour.data.singles_entry_deadline||tour.data.deadline||""
    );
    if(deadline&&gameDate>deadline&&!legacy)return h({error:"Deadline simple dépassée : "+deadline,deadline},409);

    const active=await db.from("entries")
      .select("tournament_id,entry_method,tournaments(id,name,start_date,end_date,qualifying_start_date,qualifying_end_date,main_draw_start_date)")
      .eq("player_id",playerId).eq("status","entered").neq("tournament_id",tid);
    if(active.error)return h({error:active.error.message},500);
    const entryWindow=(row:any)=>{
      const tr=Array.isArray(row?.tournaments)?row.tournaments[0]:row?.tournaments;
      const m=String(row?.entry_method||"");
      const q=m==="qualifying"||m==="protected_qualifying"||m.endsWith("_qualifying");
      return {
        start:String(q?(tr?.qualifying_start_date||tr?.start_date):(tr?.main_draw_start_date||tr?.start_date)||""),
        end:String(tr?.end_date||tr?.start_date||"")
      };
    };
    const thisQ=requestedMethod==="qualifying"||requestedMethod==="protected_qualifying"||requestedMethod.endsWith("_qualifying");
    const thisStart=String(thisQ?(tour.data.qualifying_start_date||tour.data.start_date):(tour.data.main_draw_start_date||tour.data.start_date)||"");
    const thisEnd=String(tour.data.end_date||tour.data.start_date||"");
    const conflict=(active.data??[]).find((row:any)=>{
      const w=entryWindow(row);
      return w.start&&w.end&&thisStart&&thisEnd&&w.start<=thisEnd&&thisStart<=w.end;
    });
    if(conflict&&!legacy){
      const tr=Array.isArray((conflict as any).tournaments)?(conflict as any).tournaments[0]:(conflict as any).tournaments;
      return h({error:"Conflit calendrier avec "+String(tr?.name||"un autre tournoi")+".",conflict_tournament_id:(conflict as any).tournament_id},409);
    }

    const rank=Number(elig.ranking||elig.effective_rank||0)||null;
    const requestedOn=legacy&&deadline&&gameDate>deadline?deadline:gameDate;
    const up=await db.from("entries").upsert({
      tournament_id:tid,player_id:playerId,status:"entered",entry_method:requestedMethod,
      entry_rank:rank,requested_on:requestedOn,withdrawn_on:null,
      metadata:{eligibility:elig,legacy_sync:legacy},
      updated_at:new Date().toISOString()
    },{onConflict:"tournament_id,player_id"}).select("*").single();
    if(up.error)return h({error:up.error.message},500);
    return h({ok:true,action:"enter",entry:up.data,eligibility:elig});
  }

  if(path.endsWith("/api/doubles-entry-status")&&req.method==="GET"){
    const id=n(u.searchParams.get("id"),0,1,99999999);
    const requestedPlayerId=n(u.searchParams.get("player_id"),0,0,99999999);
    const career=await db.from("career_state").select("managed_player_id").eq("id","demo").maybeSingle();
    if(career.error)return h({error:career.error.message},500);
    const playerId=Number(requestedPlayerId||career.data?.managed_player_id||0);
    if(!playerId)return h({error:"Joueur managé introuvable"},404);
    const [tr,persisted]=await Promise.all([
      db.from("tournaments").select("*").eq("id",id).eq("is_active",true).maybeSingle(),
      db.from("managed_doubles_entries")
        .select("id,owner_id,tournament_id,player_id,partner_id,status,entry_method,entry_phase,combined_rank,protected_combined_rank,projected_cut,requested_on,withdrawn_on,metadata,updated_at,partner:players!managed_doubles_entries_partner_id_fkey(id,name,country,ranking,doubles_ranking)")
        .eq("owner_id","demo").eq("tournament_id",id).eq("player_id",playerId).maybeSingle()
    ]);
    if(tr.error||persisted.error)return h({error:(tr.error||persisted.error)?.message},500);
    if(!tr.data)return h({error:"Tournoi introuvable"},404);
    try{return h({
      tournament:tr.data,player_id:playerId,
      doubles_entry_status:await managedDoublesEntryStatus(tr.data,playerId),
      managed_doubles_entry:persisted.data??null
    })}
    catch(e){return h({error:String((e as any)?.message||e)},500)}
  }

  if(path.endsWith("/api/doubles-entry")&&req.method==="POST"){
    let body:any; try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const tid=n(body?.tournament_id??body?.id,0,1,99999999);
    const action=String(body?.action||"enter").trim().toLowerCase();
    const legacy=Boolean(body?.legacy);
    if(!["enter","withdraw"].includes(action))return h({error:"Action double invalide"},400);

    const [career,tr]=await Promise.all([
      db.from("career_state").select("career_date,career_focus,managed_player_id").eq("id","demo").maybeSingle(),
      db.from("tournaments").select("*").eq("id",tid).eq("is_active",true).maybeSingle()
    ]);
    if(career.error||tr.error)return h({error:(career.error||tr.error)?.message},500);
    if(!career.data?.managed_player_id)return h({error:"Joueur managé introuvable"},404);
    if(!tr.data)return h({error:"Tournoi introuvable"},404);

    const primaryId=Number(career.data.managed_player_id||0);
    const playerId=n(body?.player_id,primaryId,1,99999999);
    const gameDate=String(career.data.career_date||AGE_REFERENCE_DATE);
    if(playerId!==primaryId){
      const roster=await db.from("academy_roster").select("id")
        .eq("player_id",playerId).eq("status","active").maybeSingle();
      if(roster.error)return h({error:roster.error.message},500);
      if(!roster.data)return h({error:"Ce joueur ne fait pas partie du groupe géré."},403);
    }

    if(action==="withdraw"){
      const wd=await db.from("managed_doubles_entries").update({
        status:"withdrawn",withdrawn_on:gameDate,updated_at:new Date().toISOString()
      }).eq("owner_id","demo").eq("tournament_id",tid).eq("player_id",playerId)
        .select("*").maybeSingle();
      if(wd.error)return h({error:wd.error.message},500);
      return h({ok:true,action:"withdraw",entry:wd.data??null});
    }

    if(!tr.data.doubles)return h({error:"Ce tournoi ne propose pas le double"},409);

    let entryStatus:any;
    try{entryStatus=await managedDoublesEntryStatus(tr.data,playerId)}
    catch(e){return h({error:String((e as any)?.message||e)},500)}
    if(entryStatus?.can_schedule===false)return h({error:entryStatus.label||"Inscription double impossible",doubles_entry_status:entryStatus},409);
    const partner:any=entryStatus?.partner||null;
    if(!partner?.id)return h({error:"Choisis d’abord un partenaire de double"},409);
    const partnership=await db.from("doubles_partnerships")
      .select("id,player_a_id,player_b_id")
      .or("player_a_id.eq."+playerId+",player_b_id.eq."+playerId)
      .order("id",{ascending:false}).limit(1).maybeSingle();
    if(partnership.error)return h({error:partnership.error.message},500);
    if(!partnership.data)return h({error:"Partenariat double introuvable"},409);

    const entryMethod=String(
      entryStatus?.requires_qualifying
        ?(entryStatus.qualifying_entry_method||"qualifying")
        :entryStatus?.projected_acceptance===false
          ?"alternate"
          :entryStatus?.use_protected_ranking
            ?"protected"
            :entryStatus?.phase==="onsite"
              ?"onsite"
              :entryStatus?.phase==="race"
                ?"race"
                :"direct"
    );
    const entryPhase=String(entryStatus?.phase||"advance");
    const calendarMode=entryStatus?.requires_qualifying?"qualifying":"direct";

    const [mineConflict,partnerConflict,otherDoubles]=await Promise.all([
      db.rpc("player_tournament_calendar_conflict",{p_player_id:playerId,p_tournament_id:tid,p_entry_method:calendarMode}),
      db.rpc("player_tournament_calendar_conflict",{p_player_id:Number(partner.id),p_tournament_id:tid,p_entry_method:calendarMode}),
      db.from("managed_doubles_entries")
        .select("tournament_id,entry_method,entry_phase,tournaments(id,name,start_date,end_date,qualifying_start_date,main_draw_start_date)")
        .eq("owner_id","demo").eq("player_id",playerId).eq("status","entered").neq("tournament_id",tid)
    ]);
    if(mineConflict.error||partnerConflict.error||otherDoubles.error)return h({error:(mineConflict.error||partnerConflict.error||otherDoubles.error)?.message},500);
    if(mineConflict.data?.conflict===true&&!legacy)return h({error:"Conflit calendrier avec un autre engagement.",schedule_conflict:mineConflict.data},409);
    if(partnerConflict.data?.conflict===true&&!legacy)return h({error:"Ton partenaire a un conflit calendrier.",partner_schedule_conflict:partnerConflict.data},409);

    const thisStart=String(
      entryStatus?.requires_qualifying
        ?(tr.data.qualifying_start_date||tr.data.start_date)
        :(tr.data.main_draw_start_date||tr.data.start_date)
    );
    const thisEnd=String(tr.data.end_date||tr.data.start_date||"");
    const doubleConflict=(otherDoubles.data??[]).find((row:any)=>{
      const t0=Array.isArray(row.tournaments)?row.tournaments[0]:row.tournaments;
      const otherStart=String(
        String(row.entry_method||"").includes("qualifying")
          ?(t0?.qualifying_start_date||t0?.start_date)
          :(t0?.main_draw_start_date||t0?.start_date)
      );
      const otherEnd=String(t0?.end_date||t0?.start_date||"");
      return otherStart&&otherEnd&&thisStart&&thisEnd&&otherStart<=thisEnd&&thisStart<=otherEnd;
    });
    if(doubleConflict&&!legacy){
      const t0=Array.isArray((doubleConflict as any).tournaments)?(doubleConflict as any).tournaments[0]:(doubleConflict as any).tournaments;
      return h({error:"Conflit double avec "+String(t0?.name||"un autre tournoi")+".",conflict_tournament_id:(doubleConflict as any).tournament_id},409);
    }

    const combined=Number(entryStatus?.score||entryStatus?.best_combined_rank||entryStatus?.doubles_combined_rank||0)||null;
    const protectedCombined=Number(entryStatus?.protected_combined_rank||0)||null;
    const projectedCut=Number(entryStatus?.requires_qualifying?entryStatus?.qualifying_cut:entryStatus?.projected_cut||0)||null;
    const requestedOn=legacy?String(body?.requested_on||gameDate):gameDate;

    const up=await db.from("managed_doubles_entries").upsert({
      owner_id:"demo",tournament_id:tid,player_id:playerId,
      partner_id:Number(partner.id),status:"entered",
      entry_method:entryMethod,entry_phase:entryPhase,
      combined_rank:combined,protected_combined_rank:protectedCombined,
      projected_cut:projectedCut,requested_on:requestedOn,withdrawn_on:null,
      metadata:{
        label:entryStatus?.label||entryMethod,
        projected_acceptance:entryStatus?.projected_acceptance,
        qualifying_cut:entryStatus?.qualifying_cut??null,
        field_band:entryStatus?.field_band??null,
        use_protected_ranking:Boolean(entryStatus?.use_protected_ranking),
        legacy_sync:legacy,
        partnership_id:partnership.data.id
      },
      updated_at:new Date().toISOString()
    },{onConflict:"owner_id,tournament_id,player_id"}).select("*").single();
    if(up.error)return h({error:up.error.message},500);

    return h({ok:true,action:"enter",entry:up.data,doubles_entry_status:entryStatus,partner});
  }

  if(path.endsWith("/api/tournament-detail")&&req.method==="GET"){
    const id=n(u.searchParams.get("id"),0,1,99999999);
    const requestedPlayerId=n(u.searchParams.get("player_id"),0,0,99999999);
    const [t,forfeits,tournamentCareer]=await Promise.all([
      db.from("tournaments").select("*").eq("id",id).eq("is_active",true).maybeSingle(),
      db.from("tournament_forfeits").select("id,player_id,reason,players(id,name,country,ranking,junior_ranking)").eq("tournament_id",id),
      db.from("career_state").select("career_date,managed_player_id").eq("id","demo").maybeSingle()
    ]);
    if(t.error||forfeits.error||tournamentCareer.error) return h({error:(t.error||forfeits.error||tournamentCareer.error)?.message},500);
    if(!t.data) return h({error:"Tournament not found"},404);
    const primaryDetailPlayerId=Number(tournamentCareer.data?.managed_player_id||0);
    const detailPlayerId=Number(requestedPlayerId||primaryDetailPlayerId||0);
    if(detailPlayerId!==primaryDetailPlayerId){
      const roster=await db.from("academy_roster").select("id").eq("player_id",detailPlayerId).eq("status","active").maybeSingle();
      if(roster.error)return h({error:roster.error.message},500);
      if(!roster.data)return h({error:"Ce joueur ne fait pas partie du groupe géré."},403);
    }
    const wc=detailPlayerId
      ?await db.from("wildcard_requests").select("*").eq("tournament_id",id).eq("player_id",detailPlayerId).maybeSingle()
      :{data:null,error:null} as any;
    if(wc.error)return h({error:wc.error.message},500);
    t.data=await resolveTournamentImage(t.data);
    const referenceDate=String(tournamentCareer.data?.career_date||AGE_REFERENCE_DATE);
    const addIsoDays=(iso:any,days:number)=>{
      if(!iso)return null;
      const d=new Date(String(iso)+"T12:00:00Z"); d.setUTCDate(d.getUTCDate()+days);
      return d.toISOString().slice(0,10);
    };
    const isoDayDiff=(a:any,b:any)=>{
      if(!a||!b)return 0;
      return Math.max(0,Math.round((new Date(String(b)+"T12:00:00Z").getTime()-new Date(String(a)+"T12:00:00Z").getTime())/86400000));
    };
    const ncaaSeasonAt=(iso:any)=>{
      const s=String(iso||AGE_REFERENCE_DATE),y=Number(s.slice(0,4))||2025,m=Number(s.slice(5,7))||1;
      const start=m>=8?y:y-1;
      return String(start)+"-"+String((start+1)%100).padStart(2,"0");
    };

    let tournamentHistory:any[]=[];
    let tournamentDoublesHistory:any[]=[];
    let tournamentHistoryRecords:any={editions:0,most_titles_name:null,most_titles:0,latest_winner:null};
    if(t.data.history_group){
      const hist=await db.from("tournament_edition_history")
        .select("id,season,final_date,tournament_name,level,surface,winner_player_id,winner_name,runner_up_player_id,runner_up_name,score,source_url,source_label,verified")
        .eq("history_group",String(t.data.history_group))
        .eq("event_type","singles")
        .order("season",{ascending:false})
        .limit(120);
      if(!hist.error){
        tournamentHistory=hist.data??[];
        const counts=new Map<string,number>();
        for(const row of tournamentHistory){
          const name=String(row.winner_name||"").trim();
          if(name)counts.set(name,(counts.get(name)||0)+1);
        }
        const top=[...counts.entries()].sort((a,b)=>b[1]-a[1]||a[0].localeCompare(b[0]))[0]||[null,0];
        tournamentHistoryRecords={
          editions:tournamentHistory.length,
          most_titles_name:top[0],
          most_titles:top[1],
          latest_winner:tournamentHistory[0]?.winner_name||null,
          latest_season:tournamentHistory[0]?.season||null
        };
      }

      const doublesHist=await db.from("tournament_doubles_edition_history")
        .select("id,season,final_date,tournament_name,level,surface,winner_a_id,winner_a_name,winner_b_id,winner_b_name,runner_a_id,runner_a_name,runner_b_id,runner_b_name,source_label")
        .eq("history_group",String(t.data.history_group))
        .not("winner_a_name","is",null)
        .order("season",{ascending:false})
        .limit(100);
      if(!doublesHist.error)tournamentDoublesHistory=doublesHist.data??[];
    }

    const drawSize=Math.max(8,Math.min(128,Number(t.data.singles_draw_size||t.data.draw_size||32)));
    const doublesDrawConfig=tournamentDoublesDrawConfig(t.data);
    const doublesDrawSize=doublesDrawConfig.drawSize;
    const doublesSeedCount=doublesDrawConfig.seedCount;
    const [run,doublesRun] = await Promise.all([
      db.from("tournament_runs").select("*")
        .eq("tournament_id",id).eq("managed_player_id",detailPlayerId)
        .order("played_at",{ascending:false}).limit(1).maybeSingle(),
      db.from("doubles_runs").select("*,partner:players(id,name,country,doubles_ranking)").eq("tournament_id",id).eq("managed_player_id",detailPlayerId).order("played_at",{ascending:false}).limit(1).maybeSingle()
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

    // World draw snapshot: after the autonomous season engine has resolved an
    // event, expose the exact seeded positions and all world matches instead of
    // falling back to an entry-list projection.
    let worldMainRows:any[]=[];
    let worldCompletedDraw:any[]=[];
    let worldQualifyingRows:any[]=[];
    let worldQualifyingDraw:any[]=[];
    let worldLuckyLosers:any[]=[];
    let worldMainBracket:any[]=[];
    let worldAcceptance:any={state:null,main:[],alternates:[],withdrawn:[],rows:[]};
    let worldQualAcceptance:any={state:null,accepted:[],alternates:[],withdrawn:[],rows:[]};
    const [worldEntriesRes,worldMatchesRes,worldQualEntriesRes,worldLuckyLoserRes,worldQualStateRes,worldAcceptanceStateRes,worldAcceptanceEntriesRes,worldQualAcceptanceStateRes,worldQualAcceptanceEntriesRes]=await Promise.all([
      db.from("world_tournament_entries")
        .select("player_id,seed,draw_slot,entry_method,ranking_at_entry,had_bye,matches_won,result_code,result_label,points_awarded,qualifying_points,prize_awarded,prize_currency,simulated_on,source_label")
        .eq("tournament_id",id)
        .order("draw_slot",{ascending:true}),
      db.from("world_tournament_matches")
        .select("id,round_no,round_code,group_name,match_no,player_a_id,player_b_id,winner_id,loser_id,score,best_of,player_a_win_probability,simulated_on,is_qualifying")
        .eq("tournament_id",id)
        .order("round_no",{ascending:true})
        .order("match_no",{ascending:true}),
      db.from("world_tournament_qualifying_entries")
        .select("player_id,entry_method,ranking_at_entry,result_code,result_label,qualified,points_awarded,last_opponent_id,last_opponent_name,last_score,simulated_on,source_label,seed,draw_pos,section_no")
        .eq("tournament_id",id)
        .order("draw_pos",{ascending:true,nullsFirst:false})
        .order("ranking_at_entry",{ascending:true}),
      db.from("world_tournament_lucky_losers")
        .select("player_id,loss_round_code,ranking_at_seeding,ll_order,selected,source_label,created_at")
        .eq("tournament_id",id)
        .order("ll_order",{ascending:true}),
      db.from("world_qualifying_states")
        .select("status,draw_size,bracket_total,qualifier_slots,rounds_count,section_bracket,draw_prepared_on,current_round_no,last_advanced_on,finalized_on,metadata")
        .eq("tournament_id",id)
        .maybeSingle(),
      db.from("world_tournament_acceptance_states")
        .select("tournament_id,frozen_on,direct_slots,alternate_slots,status,last_refreshed_on,metadata")
        .eq("tournament_id",id)
        .maybeSingle(),
      db.from("world_tournament_acceptance_entries")
        .select("player_id,list_group,acceptance_order,effective_rank,status,entry_method,snapshot_date,promoted_on,withdrawn_on,withdrawal_phase,withdrawal_reason,source_label")
        .eq("tournament_id",id)
        .order("list_group",{ascending:true})
        .order("acceptance_order",{ascending:true}),
      db.from("world_qualifying_acceptance_states")
        .select("tournament_id,created_on,movement_closes_on,direct_slots,alternate_slots,status,last_refreshed_on,metadata")
        .eq("tournament_id",id)
        .maybeSingle(),
      db.from("world_qualifying_acceptance_entries")
        .select("player_id,list_group,acceptance_order,effective_rank,status,entry_method,snapshot_date,promoted_on,withdrawn_on,withdrawal_phase,withdrawal_reason,source_label")
        .eq("tournament_id",id)
        .order("list_group",{ascending:true})
        .order("acceptance_order",{ascending:true})
    ]);
    if(worldEntriesRes.error||worldMatchesRes.error||worldQualEntriesRes.error||worldLuckyLoserRes.error||worldQualStateRes.error||worldAcceptanceStateRes.error||worldAcceptanceEntriesRes.error||worldQualAcceptanceStateRes.error||worldQualAcceptanceEntriesRes.error){
      return h({error:(worldEntriesRes.error||worldMatchesRes.error||worldQualEntriesRes.error||worldLuckyLoserRes.error||worldQualStateRes.error||worldAcceptanceStateRes.error||worldAcceptanceEntriesRes.error||worldQualAcceptanceStateRes.error||worldQualAcceptanceEntriesRes.error)?.message},500);
    }
    const worldPlayerIds=[...new Set([
      ...(worldEntriesRes.data??[]).map((x:any)=>Number(x.player_id||0)),
      ...(worldMatchesRes.data??[]).flatMap((x:any)=>[Number(x.player_a_id||0),Number(x.player_b_id||0),Number(x.winner_id||0),Number(x.loser_id||0)]),
      ...(worldQualEntriesRes.data??[]).map((x:any)=>Number(x.player_id||0)),
      ...(worldLuckyLoserRes.data??[]).map((x:any)=>Number(x.player_id||0)),
      ...(worldAcceptanceEntriesRes.data??[]).map((x:any)=>Number(x.player_id||0)),
      ...(worldQualAcceptanceEntriesRes.data??[]).map((x:any)=>Number(x.player_id||0))
    ].filter(Boolean))];
    let worldPlayerMap=new Map<number,any>();
    if(worldPlayerIds.length){
      const wp=await db.from("players")
        .select("id,name,country,ranking,doubles_ranking,junior_ranking,points,form,fitness,fatigue,current_ability,potential")
        .in("id",worldPlayerIds);
      if(wp.error)return h({error:wp.error.message},500);
      worldPlayerMap=new Map((wp.data??[]).map((p:any)=>[Number(p.id),p]));
    }
    const acceptanceRows=(worldAcceptanceEntriesRes.data??[]).map((x:any)=>{
      const p:any=worldPlayerMap.get(Number(x.player_id))||{};
      return {
        ...p,id:Number(x.player_id),player_id:Number(x.player_id),
        ranking:Number(x.effective_rank||p.ranking||999999),
        effective_rank:Number(x.effective_rank||p.ranking||999999),
        list_group:x.list_group,acceptance_order:Number(x.acceptance_order||0),
        status:x.status,entry_method:x.entry_method,snapshot_date:x.snapshot_date,
        promoted_on:x.promoted_on,withdrawn_on:x.withdrawn_on,
        withdrawal_phase:x.withdrawal_phase,withdrawal_reason:x.withdrawal_reason,
        source_label:x.source_label
      };
    });
    worldAcceptance={
      state:worldAcceptanceStateRes.data??null,
      main:acceptanceRows.filter((x:any)=>x.status==="accepted"||x.status==="promoted"),
      alternates:acceptanceRows.filter((x:any)=>x.status==="alternate"),
      withdrawn:acceptanceRows.filter((x:any)=>x.status==="withdrawn"),
      rows:acceptanceRows
    };
    const qualAcceptanceRows=(worldQualAcceptanceEntriesRes.data??[]).map((x:any)=>{
      const p:any=worldPlayerMap.get(Number(x.player_id))||{};
      return {
        ...p,id:Number(x.player_id),player_id:Number(x.player_id),
        ranking:Number(x.effective_rank||p.ranking||999999),
        effective_rank:Number(x.effective_rank||p.ranking||999999),
        list_group:x.list_group,acceptance_order:Number(x.acceptance_order||0),
        status:x.status,entry_method:x.entry_method,snapshot_date:x.snapshot_date,
        promoted_on:x.promoted_on,withdrawn_on:x.withdrawn_on,
        withdrawal_phase:x.withdrawal_phase,withdrawal_reason:x.withdrawal_reason,
        source_label:x.source_label
      };
    });
    worldQualAcceptance={
      state:worldQualAcceptanceStateRes.data??null,
      accepted:qualAcceptanceRows.filter((x:any)=>x.status==="accepted"||x.status==="promoted"),
      alternates:qualAcceptanceRows.filter((x:any)=>x.status==="alternate"),
      withdrawn:qualAcceptanceRows.filter((x:any)=>x.status==="withdrawn"),
      rows:qualAcceptanceRows
    };
    const pendingForfeitIds=new Set((forfeits.data??[]).map((x:any)=>Number(x.player_id||0)).filter(Boolean));
    worldMainRows=(worldEntriesRes.data??[]).map((x:any)=>{
      const p:any=worldPlayerMap.get(Number(x.player_id))||{};
      const withdrawnPending=pendingForfeitIds.has(Number(x.player_id));
      return {
        ...p,
        id:Number(x.player_id),
        ranking:Number(x.ranking_at_entry||p.ranking||999999),
        seed:x.seed,
        draw_slot:x.draw_slot,
        entry_method:withdrawnPending?"withdrawn_pending":x.entry_method,
        withdrawn_pending:withdrawnPending,
        withdrawn_player_id:withdrawnPending?Number(x.player_id):null,
        had_bye:Boolean(x.had_bye),
        matches_won:Number(x.matches_won||0),
        result:x.result_label||x.result_code||null,
        result_code:x.result_code,
        points_awarded:Number(x.points_awarded||0),
        qualifying_points:Number(x.qualifying_points||0),
        prize_awarded:Number(x.prize_awarded||0),
        prize_currency:x.prize_currency||null,
        simulated_on:x.simulated_on,
        source_label:x.source_label,
        actual_draw:true
      };
    });
    const roundName=(code:any)=>{
      const c=String(code||"");
      return c==="F"?"Finale":c==="SF"?"Demi-finales":c==="QF"?"Quarts de finale":
        c==="R16"?"Huitièmes":c==="R32"?"2e tour / R32":c==="R64"?"R64":
        c==="R128"?"R128":c.startsWith("Q")?"Qualifications "+c:c||"Tour";
    };
    const rawMainMatches=(worldMatchesRes.data??[]).filter((x:any)=>!x.is_qualifying);
    const mainStartDate=String(t.data.main_draw_start_date||t.data.start_date||referenceDate);
    const mainEndDate=String(t.data.end_date||mainStartDate);
    const mainSpan=isoDayDiff(mainStartDate,mainEndDate);
    const mainBracketSize=Math.pow(2,Math.ceil(Math.log2(Math.max(2,drawSize))));
    const mainRoundCount=Math.max(1,Math.round(Math.log2(mainBracketSize)));
    const scheduledMainDate=(roundNo:any)=>{
      const idx=Math.max(0,Number(roundNo||1)-1);
      return addIsoDays(mainStartDate,Math.min(mainSpan,Math.round(idx*mainSpan/Math.max(1,mainRoundCount-1))))||mainStartDate;
    };
    const worldEntryMeta=new Map(worldMainRows.map((x:any)=>[Number(x.id),x]));
    worldCompletedDraw=rawMainMatches.map((x:any)=>{
      const scheduledDate=scheduledMainDate(x.round_no),completed=scheduledDate<=referenceDate;
      const firstRound=Number(x.round_no||0)===1;
      const drawPublished=referenceDate>=String(t.data.qualifying_end_date||addIsoDays(mainStartDate,-1)||mainStartDate);
      const revealPlayers=completed||(firstRound&&drawPublished);
      const aMeta:any=worldEntryMeta.get(Number(x.player_a_id))||null;
      const bMeta:any=worldEntryMeta.get(Number(x.player_b_id))||null;
      const bye=String(x.score||"")==="BYE";
      return {
        id:x.id,round_no:x.round_no,round_code:x.round_code,
        round_name:Number(x.round_no||0)===1?"1er tour":roundName(x.round_code),match_no:x.match_no,
        player_a_id:revealPlayers?x.player_a_id:null,player_b_id:revealPlayers?x.player_b_id:null,
        player_a_name:revealPlayers?(x.player_a_id?(worldPlayerMap.get(Number(x.player_a_id))?.name||"—"):(bye?"BYE":"—")):"À déterminer",
        player_b_name:revealPlayers?(x.player_b_id?(worldPlayerMap.get(Number(x.player_b_id))?.name||"—"):(bye?"BYE":"—")):"À déterminer",
        player_a_seed:aMeta?.seed||null,player_b_seed:bMeta?.seed||null,
        player_a_entry:aMeta?.entry_method||(bye&&!x.player_a_id?"bye":null),
        player_b_entry:bMeta?.entry_method||(bye&&!x.player_b_id?"bye":null),
        winner_id:completed?x.winner_id:null,winner_name:completed?(worldPlayerMap.get(Number(x.winner_id))?.name||(bye?"BYE":"—")):null,
        loser_id:completed?x.loser_id:null,loser_name:completed&&x.loser_id?(worldPlayerMap.get(Number(x.loser_id))?.name||"—"):null,
        score:completed?x.score:null,best_of:x.best_of,player_a_win_probability:completed?x.player_a_win_probability:null,
        scheduled_date:scheduledDate,simulated_on:x.simulated_on,status:completed?"completed":"scheduled",source:"world_engine"
      };
    });
    worldQualifyingRows=(worldQualEntriesRes.data??[]).map((x:any)=>({
      ...(worldPlayerMap.get(Number(x.player_id))||{}),id:Number(x.player_id),ranking:Number(x.ranking_at_entry||999999),
      entry_method:x.entry_method,result:x.result_label||x.result_code,result_code:x.result_code,qualified:Boolean(x.qualified),
      points_awarded:Number(x.points_awarded||0),last_opponent_id:x.last_opponent_id,last_opponent_name:x.last_opponent_name,
      last_score:x.last_score,simulated_on:x.simulated_on,source_label:x.source_label,
      seed:x.seed,draw_pos:x.draw_pos,section_no:x.section_no,actual_draw:true
    }));
    const worldQualMeta=new Map(worldQualifyingRows.map((x:any)=>[Number(x.id),x]));
    worldQualifyingDraw=(worldMatchesRes.data??[])
      .filter((x:any)=>Boolean(x.is_qualifying))
      .map((x:any)=>{
        const aMeta:any=worldQualMeta.get(Number(x.player_a_id))||null;
        const bMeta:any=worldQualMeta.get(Number(x.player_b_id))||null;
        const bye=String(x.score||"")==="BYE";
        const completed=Boolean(x.winner_id)||bye;
        return {
          id:x.id,round_no:x.round_no,round_code:x.round_code,round_name:roundName(x.round_code),match_no:x.match_no,
          player_a_id:x.player_a_id,player_b_id:x.player_b_id,
          player_a_name:x.player_a_id?(worldPlayerMap.get(Number(x.player_a_id))?.name||"—"):(bye?"BYE":"—"),
          player_b_name:x.player_b_id?(worldPlayerMap.get(Number(x.player_b_id))?.name||"—"):(bye?"BYE":"—"),
          player_a_seed:aMeta?.seed||null,player_b_seed:bMeta?.seed||null,
          player_a_entry:aMeta?.entry_method||(bye&&!x.player_a_id?"bye":null),
          player_b_entry:bMeta?.entry_method||(bye&&!x.player_b_id?"bye":null),
          winner_id:completed?x.winner_id:null,
          winner_name:completed&&x.winner_id?(worldPlayerMap.get(Number(x.winner_id))?.name||"—"):null,
          loser_id:completed?x.loser_id:null,
          loser_name:completed&&x.loser_id?(worldPlayerMap.get(Number(x.loser_id))?.name||"—"):null,
          score:completed?x.score:null,best_of:x.best_of,
          scheduled_date:x.simulated_on,simulated_on:x.simulated_on,
          status:completed?"completed":"scheduled",source:"world_qualifying_engine"
        };
      })
      .sort((a:any,b:any)=>Math.abs(Number(a.round_no))-Math.abs(Number(b.round_no))||Number(a.match_no)-Number(b.match_no));
    worldLuckyLosers=(worldLuckyLoserRes.data??[]).map((x:any)=>({
      player_id:Number(x.player_id),name:worldPlayerMap.get(Number(x.player_id))?.name||"—",
      country:worldPlayerMap.get(Number(x.player_id))?.country||null,
      ranking:Number(x.ranking_at_seeding||worldPlayerMap.get(Number(x.player_id))?.ranking||999999),
      loss_round_code:x.loss_round_code,ll_order:Number(x.ll_order||0),selected:Boolean(x.selected),source_label:x.source_label
    }));
    if(!completedDraw.length&&worldCompletedDraw.length)completedDraw=worldCompletedDraw.filter((x:any)=>x.status==="completed");
    const entryDeadline=String(t.data.main_entry_deadline||t.data.singles_entry_deadline||t.data.deadline||"");
    const withdrawalDeadline=String(t.data.withdrawal_deadline||t.data.singles_withdrawal_deadline||t.data.freeze_deadline||"");
    const qSignIn=String(t.data.qualifying_signin_date||""),qStart=String(t.data.qualifying_start_date||"");
    const qEnd=String(t.data.qualifying_end_date||qStart||""),mainStart=String(t.data.main_draw_start_date||t.data.start_date||"");
    const mainDrawDate=String(qEnd||addIsoDays(mainStart,-1)||mainStart),finalDate=String(t.data.end_date||mainStart||"");
    const lifecycleStep=(key:string,label:string,date:string)=>!date?null:{key,label,date,status:date<referenceDate?"done":date===referenceDate?"today":"upcoming"};
    const drawTimeline=[
      lifecycleStep("entry_deadline","Clôture entry list",entryDeadline),lifecycleStep("withdrawal_deadline","Deadline retraits / alternates",withdrawalDeadline),
      lifecycleStep("q_signin","Sign-in qualifications",qSignIn),lifecycleStep("q_start","Début qualifications",qStart),
      lifecycleStep("q_end","Fin qualifications / ordre LL",qEnd),lifecycleStep("main_draw","Tirage tableau principal",mainDrawDate),
      lifecycleStep("main_start","Début tableau principal",mainStart),lifecycleStep("final","Finale",finalDate)
    ].filter(Boolean);
    let drawPhase="entry_list";
    if(qStart&&referenceDate>=qStart&&referenceDate<=qEnd)drawPhase="qualifying";
    else if(mainStart&&referenceDate<mainStart&&(!entryDeadline||referenceDate>=entryDeadline))drawPhase="draw";
    else if(mainStart&&finalDate&&referenceDate>=mainStart&&referenceDate<=finalDate)drawPhase="live";
    else if(finalDate&&referenceDate>finalDate)drawPhase="completed";

    let worldDoublesEntries:any[]=[];
    let worldDoublesBracket:any[]=[];
    if(t.data.doubles){
      const [worldDoublesEntryRes,worldDoublesMatchRes]=await Promise.all([
        db.from("world_doubles_tournament_entries")
          .select("pair_id,entry_method,seed,draw_slot,had_bye,matches_won,result_code,result_label,points_awarded,prize_awarded,last_opponent_pair_id,last_score,simulated_on,source_label")
          .eq("tournament_id",id)
          .order("draw_slot",{ascending:true}),
        db.from("world_doubles_tournament_matches")
          .select("id,round_no,round_code,match_no,pair_a_id,pair_b_id,winner_pair_id,loser_pair_id,score,pair_a_win_probability,model_version,simulated_on,is_qualifying")
          .eq("tournament_id",id)
          .eq("is_qualifying",false)
          .order("round_no",{ascending:true})
          .order("match_no",{ascending:true})
      ]);
      if(worldDoublesEntryRes.error||worldDoublesMatchRes.error){
        return h({error:(worldDoublesEntryRes.error||worldDoublesMatchRes.error)?.message},500);
      }
      const pairIds=[...new Set([
        ...(worldDoublesEntryRes.data??[]).map((x:any)=>Number(x.pair_id||0)),
        ...(worldDoublesMatchRes.data??[]).flatMap((x:any)=>[
          Number(x.pair_a_id||0),Number(x.pair_b_id||0),Number(x.winner_pair_id||0),Number(x.loser_pair_id||0)
        ])
      ].filter(Boolean))];
      if(pairIds.length){
        const pairRes=await db.from("world_doubles_partnerships")
          .select("id,player_a_id,player_b_id,chemistry,compatibility,pair_strength")
          .in("id",pairIds);
        if(pairRes.error)return h({error:pairRes.error.message},500);
        const playerIds=[...new Set((pairRes.data??[]).flatMap((x:any)=>[Number(x.player_a_id||0),Number(x.player_b_id||0)]).filter(Boolean))];
        const playerRes=playerIds.length
          ?await db.from("players").select("id,name,country,doubles_ranking").in("id",playerIds)
          :{data:[],error:null};
        if(playerRes.error)return h({error:playerRes.error.message},500);
        const pMap=new Map((playerRes.data??[]).map((p:any)=>[Number(p.id),p]));
        const pairMap=new Map((pairRes.data??[]).map((p:any)=>{
          const a:any=pMap.get(Number(p.player_a_id))||{},b:any=pMap.get(Number(p.player_b_id))||{};
          return [Number(p.id),{
            id:Number(p.id),
            player_a_id:Number(p.player_a_id),player_b_id:Number(p.player_b_id),
            player_ids:[Number(p.player_a_id),Number(p.player_b_id)],
            name:String(a.name||"—")+" / "+String(b.name||"—"),
            player_a:a,player_b:b,
            combined_rank:Number(a.doubles_ranking||999999)+Number(b.doubles_ranking||999999),
            chemistry:Number(p.chemistry||0),compatibility:Number(p.compatibility||0),pair_strength:Number(p.pair_strength||0)
          }];
        }));
        const entryMap=new Map((worldDoublesEntryRes.data??[]).map((e:any)=>[Number(e.pair_id),e]));
        worldDoublesEntries=(worldDoublesEntryRes.data??[]).map((e:any)=>{
          const pair:any=pairMap.get(Number(e.pair_id))||{};
          return {
            ...pair,
            id:Number(e.pair_id),
            seed:e.seed,draw_slot:e.draw_slot,entry_method:e.entry_method,had_bye:Boolean(e.had_bye),
            matches_won:Number(e.matches_won||0),result_code:e.result_code,result_label:e.result_label,
            points_awarded:Number(e.points_awarded||0),prize_awarded:Number(e.prize_awarded||0),
            simulated_on:e.simulated_on,source_label:e.source_label
          };
        });
        worldDoublesBracket=(worldDoublesMatchRes.data??[]).map((m:any)=>{
          const a:any=pairMap.get(Number(m.pair_a_id))||null,b:any=pairMap.get(Number(m.pair_b_id))||null;
          const ae:any=entryMap.get(Number(m.pair_a_id))||null,be:any=entryMap.get(Number(m.pair_b_id))||null;
          const winner:any=pairMap.get(Number(m.winner_pair_id))||null;
          return {
            id:m.id,round_no:m.round_no,round_code:m.round_code,round_name:roundName(m.round_code),match_no:m.match_no,
            player_a_id:m.pair_a_id,player_b_id:m.pair_b_id,
            player_a_ids:a?.player_ids||[],player_b_ids:b?.player_ids||[],
            player_a_name:a?.name||"À déterminer",player_b_name:b?.name||"À déterminer",
            player_a_seed:ae?.seed||null,player_b_seed:be?.seed||null,
            player_a_entry:ae?.entry_method||null,player_b_entry:be?.entry_method||null,
            winner_pair_id:m.winner_pair_id,winner_pair_name:winner?.name||null,
            loser_pair_id:m.loser_pair_id,
            score:m.score,scheduled_date:m.simulated_on,simulated_on:m.simulated_on,
            status:m.winner_pair_id?"completed":"scheduled",source:"world_doubles_engine"
          };
        });
      }
    }

    let doublesMain:any[]=[];
    if(t.data.doubles){
      const isJuniorDouble=String(t.data.circuit)==="Junior";
      const categoryName=String(t.data.category||"");
      const isJuniorDoubleFinals=/Junior Double Finals/i.test(categoryName);
      const isAtpDoubleFinals=String(t.data.circuit)==="ATP"&&/ATP Finals/i.test(categoryName);

      if(isJuniorDoubleFinals){
        const race=await db.rpc("junior_doubles_race_for_date",{p_date:String((await db.from("career_state").select("career_date").eq("id","demo").maybeSingle()).data?.career_date||AGE_REFERENCE_DATE)});
        if(!race.error){
          doublesMain=(race.data??[]).slice(0,8).map((x:any)=>({
            seed:x.junior_doubles_race_ranking,
            player_a:{id:x.player_one_id,name:x.player_one,country:x.country,doubles_ranking:x.junior_doubles_race_ranking},
            player_b:{id:x.player_two_id,name:x.player_two,country:x.country,doubles_ranking:x.junior_doubles_race_ranking},
            team_name:x.name,
            combined_rank:Number(x.junior_doubles_race_ranking||9999),
            race_rank:x.junior_doubles_race_ranking,
            race_points:x.junior_doubles_race_points,
            finals_status:x.finals_status,
            source:"junior-doubles-race"
          }));
        }
      }else if(isAtpDoubleFinals){
        const careerNow=await db.from("career_state").select("career_date").eq("id","demo").maybeSingle();
        const refDate=String(careerNow.data?.career_date||AGE_REFERENCE_DATE);
        const race=await db.rpc("doubles_race_for_date",{p_date:refDate});
        if(!race.error){
          const qualified:any[]=[];
          const used=new Set<number>();
          for(const x of race.data??[]){
            const aid=Number((x as any).player_one_id||0),bid=Number((x as any).player_two_id||0);
            if(!aid||!bid||aid===bid||used.has(aid)||used.has(bid))continue;
            qualified.push(x);used.add(aid);used.add(bid);
            if(qualified.length>=8)break;
          }
          doublesMain=qualified.map((x:any)=>({
              seed:x.doubles_race_ranking,
              player_a:{id:x.player_one_id,name:x.player_one,country:x.country,doubles_ranking:x.doubles_race_ranking},
              player_b:{id:x.player_two_id,name:x.player_two,country:x.country,doubles_ranking:x.doubles_race_ranking},
              team_name:x.name,
              combined_rank:Number(x.doubles_race_ranking||9999),
              race_rank:x.doubles_race_ranking,
              race_points:x.doubles_race_points,
              finals_status:"qualified",
              source:"atp-doubles-race"
            }));
        }
      }else{
        if(!isJuniorDouble){
          const careerNow=await db.from("career_state").select("career_date").eq("id","demo").maybeSingle();
          const refDate=String(careerNow.data?.career_date||AGE_REFERENCE_DATE);
          const refYear=Number(refDate.slice(0,4));
          if(refYear>2025){
            const wp=await db.from("world_doubles_partnerships")
              .select("id,race_rank,race_points,chemistry,compatibility,pair_strength,affinity_score,player_a:players!world_doubles_partnerships_player_a_id_fkey(id,name,country,doubles_ranking,current_ability,potential),player_b:players!world_doubles_partnerships_player_b_id_fkey(id,name,country,doubles_ranking,current_ability,potential)")
              .eq("season",refYear)
              .eq("active",true)
              .order("race_rank",{ascending:true})
              .limit(Math.min(512,Math.max(128,doublesDrawSize*8)));
            if(!wp.error){
              const selected:any[]=[];
              const used=new Set<number>();
              const wanted=doublesDrawSize;
              for(const x of wp.data??[]){
                const aid=Number((x as any).player_a?.id||0);
                const bid=Number((x as any).player_b?.id||0);
                if(!aid||!bid||aid===bid||used.has(aid)||used.has(bid))continue;
                selected.push(x);used.add(aid);used.add(bid);
                if(selected.length>=wanted)break;
              }
              doublesMain=selected.map((x:any,i:number)=>({
                seed:i<doublesSeedCount?i+1:null,
                player_a:x.player_a,
                player_b:x.player_b,
                team_name:String(x.player_a?.name||"")+" / "+String(x.player_b?.name||""),
                combined_rank:Number(x.player_a?.doubles_ranking||9999)+Number(x.player_b?.doubles_ranking||9999),
                race_rank:x.race_rank,
                race_points:x.race_points,
                chemistry:x.chemistry,
                compatibility:x.compatibility,
                pair_strength:x.pair_strength,
                affinity_score:x.affinity_score,
                source:"affinity-pair"
              }));
            }
          }
        }

        if(!isJuniorDouble&&doublesMain.length<doublesDrawSize){
          const careerNow=await db.from("career_state").select("career_date").eq("id","demo").maybeSingle();
          const refDate=String(careerNow.data?.career_date||AGE_REFERENCE_DATE);
          const existingIds=doublesMain.flatMap((x:any)=>[Number(x.player_a?.id||0),Number(x.player_b?.id||0)]).filter(Boolean);
          const projected=await projectedDoublesTournamentRows(t.data,refDate,doublesDrawSize-doublesMain.length,existingIds);
          if(!projected.error&&projected.rows.length){
            const ids=[...new Set(projected.rows.flatMap((x:any)=>[Number(x.player_one_id),Number(x.player_two_id)]).filter(Boolean))];
            const profiles=ids.length
              ?await db.from("players").select("id,name,country,doubles_ranking,current_ability,potential").in("id",ids)
              :{data:[],error:null};
            if(!profiles.error){
              const byId=new Map((profiles.data??[]).map((p:any)=>[Number(p.id),p]));
              for(const row of projected.rows){
                const a:any=byId.get(Number(row.player_one_id));
                const c:any=byId.get(Number(row.player_two_id));
                if(!a||!c)continue;
                doublesMain.push({
                  seed:doublesMain.length<doublesSeedCount?doublesMain.length+1:null,
                  player_a:a,
                  player_b:c,
                  team_name:String(row.name||a.name+" / "+c.name),
                  combined_rank:Number(a.doubles_ranking||9999)+Number(c.doubles_ranking||9999),
                  race_rank:Number(row.doubles_race_ranking||9999),
                  race_points:Number(row.doubles_race_points||0),
                  source:"doubles-race-projection"
                });
                if(doublesMain.length>=doublesDrawSize)break;
              }
            }
          }
        }

        if(doublesMain.length<doublesDrawSize){
          let dpool:any;
          if(isJuniorDouble){
            dpool=await db.from("players")
              .select("id,name,country,junior_doubles_ranking,junior_doubles_points,junior_doubles_snapshot_date,junior_doubles_source,current_ability,potential")
              .not("junior_doubles_ranking","is",null)
              .or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*")
              .order("junior_doubles_ranking",{ascending:true})
              .limit(Math.min(256,Math.max(32,doublesDrawSize*2)));
          }else{
            dpool=await db.from("players")
              .select("id,name,country,doubles_ranking,doubles_points,doubles_snapshot_date,doubles_source,current_ability,potential")
              .eq("is_real",true)
              .not("doubles_ranking","is",null)
              .or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*")
              .order("doubles_ranking",{ascending:true})
              .limit(Math.min(256,Math.max(32,doublesDrawSize*2)));
          }
          if(!dpool.error){
            const arr=dpool.data??[];
            const used=new Set<number>(doublesMain.flatMap((x:any)=>[Number(x.player_a?.id||0),Number(x.player_b?.id||0)]).filter(Boolean));
            let pending:any=null;
            for(const candidate of arr){
              const cid=Number(candidate?.id||0);
              if(!cid||used.has(cid))continue;
              if(!pending){pending=candidate;continue}
              const a:any=pending,b:any=candidate;pending=null;
              const ar=isJuniorDouble?a.junior_doubles_ranking:a.doubles_ranking;
              const br=isJuniorDouble?b.junior_doubles_ranking:b.doubles_ranking;
              doublesMain.push({
                seed:doublesMain.length<doublesSeedCount?doublesMain.length+1:null,
                player_a:{...a,doubles_ranking:ar},
                player_b:{...b,doubles_ranking:br},
                team_name:String(a.name)+" / "+String(b.name),
                combined_rank:Number(ar||9999)+Number(br||9999),
                source:isJuniorDouble?"junior-ranking-projection":"ranking-projection"
              });
              used.add(Number(a.id));used.add(Number(b.id));
              if(doublesMain.length>=doublesDrawSize)break;
            }
          }
        }
      }
    }

    if(t.data.doubles&&doublesMain.length){
      const pairKey=(x:any)=>[Number(x?.player_a?.id||0),Number(x?.player_b?.id||0)].sort((a,b)=>a-b).join(":");
      const seedMetric=(x:any)=>{
        const rr=Number(x?.race_rank);
        if(Number.isFinite(rr)&&rr>0&&rr<9999)return rr;
        const cr=Number(x?.combined_rank);
        return Number.isFinite(cr)&&cr>0?cr:999999;
      };
      const seedOrder=doublesMain.slice().sort((a:any,c:any)=>
        seedMetric(a)-seedMetric(c)
        ||Number(a?.player_a?.doubles_ranking||99999)+Number(a?.player_b?.doubles_ranking||99999)
          -Number(c?.player_a?.doubles_ranking||99999)-Number(c?.player_b?.doubles_ranking||99999)
        ||pairKey(a).localeCompare(pairKey(c))
      );
      const seedMap=new Map(seedOrder.slice(0,Math.min(doublesSeedCount,seedOrder.length)).map((x:any,i:number)=>[pairKey(x),i+1]));
      for(const pair of doublesMain)pair.seed=seedMap.get(pairKey(pair))||null;
    }

    const specialTeamEvent=specialTeamEventMeta(t.data);
    if(specialTeamEvent){
      return h({
        tournament:t.data,main:[],qualifying:[],wildcard:null,forfeits:forfeits.data??[],
        run:run.data??null,doubles_run:doublesRun.data??null,doubles_main:[],doubles_completed_draw:[],completed_draw:completedDraw,
        tournament_history:tournamentHistory,tournament_doubles_history:tournamentDoublesHistory,tournament_history_records:tournamentHistoryRecords,
        format_rule:null,entry_rules:null,doubles_entry_status:null,
        ranking_kind:"team",special_team_event:specialTeamEvent,entry_preview_model:"team_selection_v1"
      });
    }

    if(String(t.data.circuit)==="Junior"){
      const [entered,juniorFormatRes]=await Promise.all([
        db.from("junior_tournament_entries")
          .select("id,seed,result,snapshot_date,source_url,players(id,name,country,age,age_snapshot_date,birth_date,junior_ranking,junior_points,current_ability,potential,form,fitness,fatigue,style)")
          .eq("tournament_id",id),
        db.from("tournament_format_rules")
          .select("rule_key,format_type,main_draw_size,bracket_size,qualifying_draw_size,doubles_draw_size,seed_count,qualifier_count,wildcard_count,rounds,points_by_result,qualifying_points,source_label,source_url")
          .eq("circuit","Junior")
          .eq("category",String(t.data.category||""))
          .eq("main_draw_size",drawSize)
          .limit(1).maybeSingle()
      ]);
      if(entered.error||juniorFormatRes.error)return h({error:(entered.error||juniorFormatRes.error)?.message},500);
      const jfr:any=juniorFormatRes.data||juniorTournamentFormatRule(t.data);
      const juniorQDraw=Math.max(0,Number(t.data.qualifying_draw_size||jfr.qualifying_draw_size||0));
      const juniorQSlots=Math.max(0,Number(jfr.qualifier_count||0));
      const juniorWcSlots=Math.max(0,Number(jfr.wildcard_count||0));
      const juniorDirectSlots=Math.max(0,drawSize-juniorQSlots-juniorWcSlots);

      let main:any[]=[];
      let qualifying:any[]=[];
      if((entered.data??[]).length){
        const entryIds=(entered.data??[])
          .map((x:any)=>Array.isArray(x.players)?x.players[0]?.id:x.players?.id)
          .filter(Boolean)
          .map(Number);
        const poolRanks=entryIds.length
          ?await db.from("junior_display_pool").select("player_id,display_rank").in("player_id",entryIds)
          :{data:[],error:null};
        if(poolRanks.error)return h({error:poolRanks.error.message},500);
        const rankMap=new Map((poolRanks.data??[]).map((x:any)=>[Number(x.player_id),Number(x.display_rank)]));
        main=(entered.data??[])
          .map((x:any)=>{
            const p=Array.isArray(x.players)?x.players[0]:x.players;
            return p?{
              ...p,
              age:ageAt(p.birth_date,AGE_REFERENCE_DATE,p.age,p.age_snapshot_date),
              ranking:rankMap.get(Number(p.id))??p.junior_ranking,
              points:p.junior_points,
              seed:x.seed,result:x.result,entry_source:x.source_url,
              entry_method:"direct"
            }:null;
          })
          .filter(Boolean)
          .sort((a:any,b:any)=>Number(a.seed||999)-Number(b.seed||999)||Number(a.ranking||9999)-Number(b.ranking||9999));
      }else if(/Junior Finals/i.test(String(t.data.category||""))){
        const careerNow=await db.from("career_state").select("career_date").eq("id","demo").maybeSingle();
        const refDate=String(careerNow.data?.career_date||AGE_REFERENCE_DATE);
        const race=await db.rpc("junior_race_for_date",{p_date:refDate});
        if(race.error)return h({error:race.error.message},500);
        main=(race.data??[]).slice(0,8).map((p:any)=>({
          ...p,
          age:ageAt(p.birth_date,AGE_REFERENCE_DATE,p.age,p.age_snapshot_date),
          ranking:p.junior_race_ranking,
          points:p.junior_race_points,
          seed:p.junior_race_ranking,
          qualification:"Junior Finals Race",
          entry_method:"direct"
        }));
      }else{
        const wanted=Math.min(400,Math.max(drawSize+juniorQDraw+juniorWcSlots+40,120));
        const pool=await db.from("junior_display_pool_view")
          .select("id,name,country,age,age_snapshot_date,birth_date,display_rank,junior_points,current_ability,potential,form,fitness,fatigue,style")
          .order("display_order",{ascending:true}).limit(wanted);
        if(pool.error)return h({error:pool.error.message},500);
        const projected=(pool.data??[]).map((p:any)=>({
          ...p,
          age:ageAt(p.birth_date,AGE_REFERENCE_DATE,p.age,p.age_snapshot_date),
          ranking:p.display_rank,
          points:p.junior_points
        }));
        const directCount=juniorDirectSlots||Math.max(0,drawSize-juniorQSlots-juniorWcSlots);
        main=projected.slice(0,directCount).map((p:any,i:number)=>({
          ...p,
          seed:i<Number(jfr.seed_count||0)?i+1:null,
          result:"Projeté",
          entry_method:"direct"
        }));
        qualifying=projected.slice(directCount,directCount+juniorQDraw).map((p:any)=>({
          ...p,
          result:"Qualifs projetées",
          entry_method:"qualifying"
        }));
        for(let i=0;i<juniorQSlots;i++){
          main.push({id:null,name:"Qualifié "+(i+1),country:null,ranking:null,points:null,seed:null,result:"À déterminer",entry_method:"qualifier_slot"});
        }
        for(let i=0;i<juniorWcSlots;i++){
          main.push({id:null,name:"Wild card "+(i+1),country:String(t.data.country||""),ranking:null,points:null,seed:null,result:"À attribuer",entry_method:"wildcard"});
        }
      }
      const visibleJuniorMain=worldMainRows.length?worldMainRows:main;
      const visibleJuniorQual=worldQualifyingRows.length?worldQualifyingRows:qualifying;
      return h({
        tournament:t.data,main:visibleJuniorMain,qualifying:visibleJuniorQual,junior_entries:entered.data??[],
        world_main:worldMainRows,world_completed_draw:worldCompletedDraw,world_qualifying:worldQualifyingRows,
      acceptance_list:worldAcceptance,qualifying_acceptance_list:worldQualAcceptance,
        main_draw_matches:worldCompletedDraw,main_draw_bracket:worldMainBracket,qualifying_draw:worldQualifyingDraw,lucky_losers:worldLuckyLosers,
        qualifying_state:worldQualStateRes.data??null,
        draw_timeline:drawTimeline,draw_phase:drawPhase,reference_date:referenceDate,
        draw_state:{actual:Boolean(worldMainRows.length),model:worldMainRows.length?"itf-junior-seed-zones-v3":"projection",seed_placement:"ITF junior regulatory zones"},
        wildcard:wc.data??null,forfeits:forfeits.data??[],run:run.data??null,doubles_run:doublesRun.data??null,
        doubles_main:doublesMain,doubles_completed_draw:doublesCompletedDraw,completed_draw:completedDraw,
        tournament_history:tournamentHistory,tournament_doubles_history:tournamentDoublesHistory,tournament_history_records:tournamentHistoryRecords,
        format_rule:jfr,
        qualifying_window:{start:t.data.qualifying_start_date||null,end:t.data.qualifying_end_date||null,draw_size:juniorQDraw,qualifier_slots:juniorQSlots},
        ranking_kind:"junior",entry_preview_model:"junior_qualifying_v1"
      });
    }

    if(String(t.data.circuit)==="NCAA"){
      const reg=await db.from("ncaa_player_registry")
        .select("ita_rank,ita_rank_official,projected_rank,school,division,season,status,snapshot_date,source_url,source_label,players(id,name,country,ranking,doubles_ranking,current_ability,potential,ncaa_current,ncaa_school,ncaa_rank)")
        .eq("season",ncaaSeasonAt(referenceDate))
        .lte("snapshot_date",referenceDate)
        .order("ita_rank",{ascending:true,nullsFirst:false})
        .limit(250);
      if(reg.error)return h({error:reg.error.message},500);
      const ncaaPlayers=(reg.data??[]).map((x:any)=>{
        const p=Array.isArray(x.players)?x.players[0]:x.players;
        return p?{
          ...p,
          ita_rank:x.ita_rank_official??null,
          ita_rank_official:x.ita_rank_official??null,
          projected_rank:x.projected_rank??null,
          registry_rank:x.ita_rank??null,
          school:x.school,
          division:x.division,
          ncaa_season:x.season,
          ncaa_status:x.status,
          ncaa_snapshot_date:x.snapshot_date,
          ncaa_source:x.source_label||x.source_url,
          ncaa_rank_type:x.ita_rank_official!=null?"official":x.projected_rank!=null?"simulated_depth":"verified_other"
        }:null;
      }).filter(Boolean);
      const individual=String(t.data.registration_mode||"")==="ncaa_individual_selection"
        ||String(t.data.registration_mode||"")==="school_nomination"
        ||String(t.data.registration_mode||"")==="conference_selection";
      return h({
        tournament:t.data,
        main:[],
        qualifying:[],
        ncaa_players:ncaaPlayers,
        ncaa_mode:t.data.registration_mode,
        ncaa_individual:individual,
        wildcard:null,
        forfeits:[],
        run:null,
        doubles_run:null,
        doubles_main:[],
        doubles_completed_draw:[],
        completed_draw:[],
        tournament_history:tournamentHistory,tournament_doubles_history:tournamentDoublesHistory,tournament_history_records:tournamentHistoryRecords,
        ranking_kind:"ncaa"
      });
    }

    const directCut=Number(t.data.direct_cut??t.data.projected_direct_cut??0);
    const qualCut=Number(t.data.qual_cut??t.data.projected_qual_cut??0);
    const isAtpSinglesFinals=String(t.data.circuit||"")==="ATP"&&/ATP Finals/i.test(String(t.data.category||""))&&!/Next Gen/i.test(String(t.data.category||""))&&Boolean(t.data.singles);
    if(isAtpSinglesFinals){
      const careerNow=await db.from("career_state").select("career_date").eq("id","demo").maybeSingle();
      const refDate=String(careerNow.data?.career_date||AGE_REFERENCE_DATE);
      const race=await db.from("players")
        .select("id,name,country,race_ranking,race_points,current_ability,potential,form,fitness,fatigue,style")
        .not("race_ranking","is",null)
        .or(`race_snapshot_date.is.null,race_snapshot_date.lte.${refDate}`)
        .or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*")
        .order("race_ranking",{ascending:true}).limit(8);
      if(race.error)return h({error:race.error.message},500);
      const main=(race.data??[]).map((p:any)=>({...p,ranking:p.race_ranking,points:p.race_points,seed:p.race_ranking,qualification:"ATP Finals Race"}));
      return h({
        tournament:t.data,main,qualifying:[],wildcard:null,forfeits:forfeits.data??[],
        run:run.data??null,doubles_run:doublesRun.data??null,doubles_main:doublesMain,doubles_completed_draw:doublesCompletedDraw,
        completed_draw:completedDraw,tournament_history:tournamentHistory,tournament_doubles_history:tournamentDoublesHistory,tournament_history_records:tournamentHistoryRecords,
        ranking_kind:"race",finals_qualification:{required:8,name:"ATP Finals Race"}
      });
    }
    const formatPreview=await db.from("tournament_format_rules")
      .select("rule_key,format_type,main_draw_size,bracket_size,qualifying_draw_size,doubles_draw_size,seed_count,qualifier_count,wildcard_count,rounds,points_by_result,qualifying_points,source_label,source_url")
      .eq("circuit",String(t.data.circuit||""))
      .eq("category",String(t.data.category||""))
      .eq("main_draw_size",drawSize)
      .limit(1).maybeSingle();
    if(formatPreview.error)return h({error:formatPreview.error.message},500);
    const fr:any=formatPreview.data||{};

    // Full progressive bracket scaffold. Only played matches carry winners/scores,
    // but every round exists visually from R1 to the final. As feeder matches
    // finish, their winners become the known participants of the next round.
    if(worldMainRows.length){
      const bracketSize=Math.max(
        Number(fr.bracket_size||0),
        Number(t.data.singles_draw_size||t.data.draw_size||0),
        ...worldMainRows.map((x:any)=>Number(x.draw_slot||0))
      );
      const roundCodes=Array.isArray(fr.rounds)&&fr.rounds.length
        ?fr.rounds.map(String)
        :Array.from({length:Math.max(1,Math.round(Math.log2(Math.max(2,bracketSize))))},(_,i)=>{
          const size=bracketSize/Math.pow(2,i);
          return size<=2?"F":size<=4?"SF":size<=8?"QF":size<=16?"R16":"R"+String(size);
        });
      const entryBySlot=new Map(worldMainRows.filter((x:any)=>Number(x.draw_slot)>0).map((x:any)=>[Number(x.draw_slot),x]));
      const entryByPlayer=new Map(worldMainRows.filter((x:any)=>Number(x.id)>0).map((x:any)=>[Number(x.id),x]));
      const existingByKey=new Map(worldCompletedDraw.map((m:any)=>[String(m.round_no)+"|"+String(m.match_no),m]));
      const scaffold:any[]=[];
      const totalSpan=isoDayDiff(String(t.data.main_draw_start_date||t.data.start_date||referenceDate),String(t.data.end_date||t.data.start_date||referenceDate));
      const scaffoldStart=String(t.data.main_draw_start_date||t.data.start_date||referenceDate);
      const scheduledFor=(roundNo:number)=>addIsoDays(
        scaffoldStart,
        roundCodes.length<=1?0:Math.min(totalSpan,Math.round((roundNo-1)*totalSpan/Math.max(1,roundCodes.length-1)))
      )||scaffoldStart;
      const feeder=(roundNo:number,matchNo:number,side:"a"|"b")=>{
        if(roundNo<=1)return null;
        const prevMatchNo=side==="a"?matchNo*2-1:matchNo*2;
        return scaffold.find((m:any)=>Number(m.round_no)===roundNo-1&&Number(m.match_no)===prevMatchNo)||null;
      };
      for(let roundNo=1;roundNo<=roundCodes.length;roundNo++){
        const matchCount=Math.max(1,Math.floor(bracketSize/Math.pow(2,roundNo)));
        for(let matchNo=1;matchNo<=matchCount;matchNo++){
          const existing:any=existingByKey.get(String(roundNo)+"|"+String(matchNo))||null;
          let aId:any=null,bId:any=null;
          if(roundNo===1){
            aId=entryBySlot.get(matchNo*2-1)?.id||null;
            bId=entryBySlot.get(matchNo*2)?.id||null;
          }else{
            aId=feeder(roundNo,matchNo,"a")?.winner_id||null;
            bId=feeder(roundNo,matchNo,"b")?.winner_id||null;
          }
          if(existing){
            if(existing.player_a_id)aId=existing.player_a_id;
            if(existing.player_b_id)bId=existing.player_b_id;
          }
          const aEntry:any=aId?entryByPlayer.get(Number(aId)):null;
          const bEntry:any=bId?entryByPlayer.get(Number(bId)):null;
          const scheduledDate=existing?.scheduled_date||scheduledFor(roundNo);
          scaffold.push({
            id:existing?.id||null,
            round_no:roundNo,
            round_code:String(roundCodes[roundNo-1]||existing?.round_code||""),
            round_name:roundName(roundCodes[roundNo-1]||existing?.round_code),
            match_no:matchNo,
            player_a_id:aId,
            player_b_id:bId,
            player_a_name:aId?(worldPlayerMap.get(Number(aId))?.name||existing?.player_a_name||"—"):"À déterminer",
            player_b_name:bId?(worldPlayerMap.get(Number(bId))?.name||existing?.player_b_name||"—"):"À déterminer",
            player_a_seed:aEntry?.seed||null,
            player_b_seed:bEntry?.seed||null,
            player_a_entry:aEntry?.entry_method||null,
            player_b_entry:bEntry?.entry_method||null,
            winner_id:existing?.winner_id||null,
            winner_name:existing?.winner_name||null,
            loser_id:existing?.loser_id||null,
            loser_name:existing?.loser_name||null,
            score:existing?.score||null,
            best_of:existing?.best_of||null,
            scheduled_date:scheduledDate,
            status:existing?.status==="completed"?"completed":scheduledDate<referenceDate?"pending_result":"scheduled",
            source:existing?"world_engine":"progressive_scaffold"
          });
        }
      }
      worldMainBracket=scaffold;
    }else{
      worldMainBracket=worldCompletedDraw;
    }

    const qSlots=Math.max(0,Number(fr.qualifier_count||0));
    const wcSlots=Math.max(0,Number(fr.wildcard_count||0));
    const directSlots=Math.max(0,drawSize-qSlots-wcSlots);
    const qDraw=Math.max(0,Number(t.data.qualifying_draw_size||fr.qualifying_draw_size||0));
    const blocked=new Set((forfeits.data??[]).map((x:any)=>Number(x.player_id)));

    const [directIds,wildcardIds,qualIds]=await Promise.all([
      db.rpc("tournament_candidate_player_ids",{p_tournament_id:id,p_entry_method:"direct",p_limit:Math.max(64,directSlots+40)}),
      wcSlots?db.rpc("tournament_candidate_player_ids",{p_tournament_id:id,p_entry_method:"wildcard",p_limit:Math.max(80,wcSlots*20)}):Promise.resolve({data:[],error:null} as any),
      qDraw?db.rpc("tournament_candidate_player_ids",{p_tournament_id:id,p_entry_method:"qualifying",p_limit:Math.max(96,qDraw+80)}):Promise.resolve({data:[],error:null} as any)
    ]);
    if(directIds.error||wildcardIds.error||qualIds.error)return h({error:(directIds.error||wildcardIds.error||qualIds.error)?.message},500);

    const rankMap=new Map<number,number>();
    const orderedDirect=(directIds.data??[]).map((x:any)=>{rankMap.set(Number(x.player_id),Number(x.effective_rank||999999));return Number(x.player_id)}).filter(Boolean);
    const orderedWild=(wildcardIds.data??[]).map((x:any)=>{rankMap.set(Number(x.player_id),Number(x.effective_rank||999999));return Number(x.player_id)}).filter(Boolean);
    const orderedQual=(qualIds.data??[]).map((x:any)=>{rankMap.set(Number(x.player_id),Number(x.effective_rank||999999));return Number(x.player_id)}).filter(Boolean);

    const allIds=[...new Set([...orderedDirect,...orderedWild,...orderedQual])];
    const playerRows=allIds.length
      ?await db.from("players").select("id,name,country,ranking,points,current_ability,potential,form,fitness,fatigue,style").in("id",allIds)
      :{data:[],error:null};
    if(playerRows.error)return h({error:playerRows.error.message},500);
    const byId=new Map<number,any>((playerRows.data??[]).map((p:any)=>[Number(p.id),{...p,ranking:rankMap.get(Number(p.id))??Number(p.ranking||999999)}]));

    const used=new Set<number>();
    const main:any[]=[];
    for(const pid of orderedDirect){
      if(main.length>=directSlots)break;
      if(blocked.has(pid)||used.has(pid)||!byId.has(pid))continue;
      main.push({...byId.get(pid),entry_method:"direct"});used.add(pid);
    }
    const wcPool=orderedWild
      .filter((pid:number)=>!blocked.has(pid)&&!used.has(pid)&&byId.has(pid))
      .map((pid:number)=>byId.get(pid))
      .sort((a:any,b:any)=>
        Number(b.country===t.data.country)-Number(a.country===t.data.country)
        ||Number(b.potential||0)-Number(a.potential||0)
        ||Number(a.ranking||999999)-Number(b.ranking||999999)
      );
    for(const p of wcPool.slice(0,wcSlots)){
      main.push({...p,entry_method:"wildcard"});used.add(Number(p.id));
    }

    const qualifying:any[]=[];
    for(const pid of orderedQual){
      if(qualifying.length>=qDraw)break;
      if(blocked.has(pid)||used.has(pid)||!byId.has(pid))continue;
      qualifying.push({...byId.get(pid),entry_method:"qualifying"});used.add(pid);
    }

    for(let qi=1;qi<=qSlots;qi++){
      main.push({
        id:null,name:"Qualifier "+qi,country:null,ranking:null,points:null,
        current_ability:null,potential:null,form:null,fitness:null,fatigue:null,style:null,
        entry_method:"qualifier_slot",projected:true
      });
    }

    const projectedSeeds=new Map(main.filter((p:any)=>p.id).sort((a:any,b:any)=>Number(a.ranking||999999)-Number(b.ranking||999999)).slice(0,Number(fr.seed_count||0)).map((p:any,i:number)=>[Number(p.id),i+1]));
    for(const p of main)p.seed=p.id?projectedSeeds.get(Number(p.id))||null:null;

    const projectedBracket=Math.max(drawSize,Number(fr.bracket_size||Math.pow(2,Math.ceil(Math.log2(Math.max(2,drawSize))))));
    const occupiedSlots=new Set<number>(),projectedByeSlots=new Set<number>();
    for(const p of main.filter((x:any)=>x.id&&x.seed).sort((a:any,b:any)=>Number(a.seed)-Number(b.seed))){
      const slotRes=await db.rpc("world_tournament_seed_slot_for_event",{p_tournament_id:id,p_bracket:projectedBracket,p_seed:Number(p.seed)});
      const slot=!slotRes.error?Number(slotRes.data||0):0;
      if(slot>0){p.draw_slot=slot;occupiedSlots.add(slot)}
    }
    const byeCount=Math.max(0,projectedBracket-drawSize);
    const byeSeeds=main.filter((x:any)=>x.id&&x.seed&&x.draw_slot).sort((a:any,b:any)=>Number(a.seed)-Number(b.seed)).slice(0,byeCount);
    for(const p of byeSeeds){
      const s=Number(p.draw_slot),opp=s%2===1?s+1:s-1;
      if(opp>=1&&opp<=projectedBracket&&!occupiedSlots.has(opp))projectedByeSlots.add(opp);
    }
    const freeSlots=Array.from({length:projectedBracket},(_,i)=>i+1).filter(s=>!occupiedSlots.has(s)&&!projectedByeSlots.has(s));
    const stableDrawKey=(p:any)=>{
      const pid=Number(p?.id||0),rank=Number(p?.ranking||999999);
      return ((pid*1103515245+id*12345+rank*97)>>>0);
    };
    const unseeded=main.filter((x:any)=>x.id&&!x.draw_slot).sort((a:any,b:any)=>stableDrawKey(a)-stableDrawKey(b)||Number(a.ranking||999999)-Number(b.ranking||999999));
    for(let i=0;i<unseeded.length&&i<freeSlots.length;i++){unseeded[i].draw_slot=freeSlots[i];occupiedSlots.add(freeSlots[i])}
    const placeholders=main.filter((x:any)=>!x.id&&!x.draw_slot);
    const leftover=freeSlots.filter(s=>!occupiedSlots.has(s));
    for(let i=0;i<placeholders.length&&i<leftover.length;i++){placeholders[i].draw_slot=leftover[i];occupiedSlots.add(leftover[i])}

    const tournamentView=projectedTournamentCuts(t.data,main,qualifying);
    const economics={
      currency:t.data.prize_currency||"USD",
      total:Number(t.data.prize_money||0),
      total_is_estimate:Boolean(t.data.prize_money_is_estimate),
      total_kind:t.data.prize_total_kind||"event_total",
      format:t.data.prize_format||"rounds",
      singles:t.data.singles_prize_by_result||{},
      qualifying:t.data.qualifying_prize_by_result||{},
      doubles:t.data.doubles_prize_by_result||{},
      special:t.data.special_prize_components||{},
      singles_is_estimate:Boolean(t.data.singles_prize_is_estimate),
      qualifying_is_estimate:Boolean(t.data.qualifying_prize_is_estimate),
      doubles_is_estimate:Boolean(t.data.doubles_prize_is_estimate),
      breakdown_is_estimate:Boolean(t.data.prize_breakdown_is_estimate),
      source_label:t.data.prize_source_label||null,
      source_url:t.data.prize_source_url||null,
      note:t.data.prize_note||null
    };

    const visibleMain=worldMainRows.length?worldMainRows:main;
    const visibleQualifying=worldQualifyingRows.length?worldQualifyingRows:qualifying;
    return h({
      tournament:tournamentView,main:visibleMain,qualifying:visibleQualifying,wildcard:wc.data??null,forfeits:forfeits.data??[],
      world_main:worldMainRows,world_completed_draw:worldCompletedDraw,world_qualifying:worldQualifyingRows,
      main_draw_matches:worldCompletedDraw,qualifying_draw:worldQualifyingDraw,lucky_losers:worldLuckyLosers,
      qualifying_state:worldQualStateRes.data??null,
      draw_timeline:drawTimeline,draw_phase:drawPhase,reference_date:referenceDate,
      projected_bye_slots:[...projectedByeSlots].sort((a,b)=>a-b),projected_bracket_size:projectedBracket,
      entry_legend:{direct:"DA",wildcard:"WC",qualifying:"Q",qualifier:"Q",qualifier_slot:"Q",lucky_loser:"LL",alternate:"ALT",special_exempt:"SE",performance_bye:"PB",bye:"BYE"},
      draw_state:{actual:Boolean(worldMainRows.length),model:worldMainRows.length?"official-seed-zones-v3":"projected-seed-zones-v3",seed_placement:"ATP/ITF regulatory zones"},
      format_rule:fr,economics,entry_rules:await managedTournamentEntryRules(t.data),doubles_entry_status:await managedDoublesEntryStatus(t.data),
      qualifying_window:{start:t.data.qualifying_start_date||null,end:t.data.qualifying_end_date||null,draw_size:qDraw,qualifier_slots:qSlots},
      run:run.data??null,doubles_run:doublesRun.data??null,doubles_main:doublesMain,doubles_completed_draw:doublesCompletedDraw,
      doubles_world_entries:worldDoublesEntries,doubles_draw_bracket:worldDoublesBracket,
      completed_draw:completedDraw,tournament_history:tournamentHistory,tournament_doubles_history:tournamentDoublesHistory,tournament_history_records:tournamentHistoryRecords,
      ranking_kind:"singles",entry_preview_model:"circuit_eligibility_v3",projected_cut_model:tournamentView.projected_cut_model
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


  if(path.endsWith("/api/training-preview")&&req.method==="POST"){
    let body:any; try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const current=await db.from("career_state").select("*").eq("id","demo").maybeSingle();
    if(current.error||!current.data)return h({error:current.error?.message||"Career missing"},500);
    const primaryPlayerId=Number(current.data.managed_player_id||0);
    const requestedPlayerId=n(body?.player_id,primaryPlayerId,1,99999999);
    const isPrimary=requestedPlayerId===primaryPlayerId;
    const managed=isPrimary
      ?await getManagedPlayer("id,name,age,birth_date,current_ability,potential,form,fitness,morale,fatigue,injury_status,career_focus")
      :await db.from("players").select("id,name,age,birth_date,current_ability,potential,form,fitness,morale,fatigue,injury_status,career_focus").eq("id",requestedPlayerId).maybeSingle();
    if(managed.error||!managed.data)return h({error:managed.error?.message||"Academy player missing"},500);
    if(!isPrimary){
      const rosterCheck=await db.from("academy_roster").select("id").eq("player_id",requestedPlayerId).eq("status","active").maybeSingle();
      if(rosterCheck.error||!rosterCheck.data)return h({error:"Ce joueur ne fait pas partie de ton académie."},403);
    }
    const [devRow,staffRows,facilityRows]=await Promise.all([
      db.from("player_development_profiles")
        .select("development_type,peak_age,decline_start_age,development_rate,professionalism,coachability,resilience,discipline,competitive_drive,coaching_environment,staff_stability,development_context,burnout_susceptibility,confidence_volatility")
        .eq("player_id",managed.data.id).maybeSingle(),
      db.from("staff").select("skill,role,profile:staff_profiles(*)"),
      db.from("facilities").select("level")
    ]);
    const dev:any=devRow.data||{};
    const sessions=Array.isArray(body?.training)?body.training.slice(0,7).map(String):[];
    const weights:any={"Service":2,"Retour":2,"Coup droit":2,"Revers":2,"Déplacements":3,"Endurance":3,"Match play":3,"Double":2,"Récupération":0,"Repos":-1};
    const load=sessions.reduce((sum:number,s:string)=>sum+Number(weights[s]??1),0);
    const playerAge=ageAt(managed.data.birth_date,String(current.data.career_date||AGE_REFERENCE_DATE),managed.data.age)||Number(managed.data.age||24);
    const fatigue=Number(isPrimary?current.data.fatigue:(managed.data as any).fatigue||0);
    const fitness=Number(isPrimary?current.data.fitness:(managed.data as any).fitness||90);
    const morale=Number(isPrimary?current.data.morale:(managed.data as any).morale||70);
    const injury=String((isPrimary?current.data.injury_status:(managed.data as any).injury_status)||"Fit");
    const careerFocus=String((isPrimary?current.data.career_focus:(managed.data as any).career_focus)||"mixed");
    const difficultyKey=["discovery","normal","manager","hardcore"].includes(String(body?.difficulty||"normal"))?String(body?.difficulty||"normal"):"normal";
    const difficultyTrainingMult=({discovery:1.12,normal:1,manager:.94,hardcore:.88} as any)[difficultyKey]||1;
    const personalBase=Math.max(.76,Math.min(1.26,
      .72+Number(dev.development_rate||10)*.012+Number(dev.professionalism||10)*.010+Number(dev.coachability||10)*.011+Number(dev.staff_stability||8)*.004
    ));
    const ageMult=playerAge<Number(dev.peak_age||25)?1.05:playerAge<=Number(dev.decline_start_age||30)?1:Math.max(.68,1-(playerAge-Number(dev.decline_start_age||30))*.055);
    const conditionMult=Math.max(.66,Math.min(1.08,.88+fitness/500+morale/700-fatigue/550-(injury!=="Fit"?.12:0)));
    const staffList=staffRows.data??[];
    const profiles=staffList.map((x:any)=>Array.isArray(x.profile)?x.profile[0]:x.profile).filter(Boolean);
    const staffEfficiency=(p:any)=>{
      const burnout=Number(p?.burnout||0),travel=Number(p?.travel_fatigue||0),workload=Number(p?.workload||20),pro=Number(p?.professionalism||10);
      return Math.max(.60,Math.min(1.06,1-burnout*.0032-travel*.0018-Math.max(0,workload-75)*.0015+Math.max(0,pro-14)*.006));
    };
    const avgStaff=staffList.length?staffList.reduce((sum:number,x:any)=>sum+Number(x.skill||10),0)/staffList.length:10;
    const best=(key:string,fallback=avgStaff)=>profiles.length?Math.max(fallback,...profiles.map((p:any)=>Number(p?.[key]||0)*staffEfficiency(p))):fallback;
    const sessionStaff=(session:string)=>{
      if(session==="Service")return (best("serve_coaching_rating")+best("technical_rating"))/2;
      if(session==="Retour")return (best("return_coaching_rating")+best("tactical_rating"))/2;
      if(session==="Double")return (best("doubles_coaching_rating")+best("tactical_rating")+best("communication_rating"))/3;
      if(session==="Coup droit"||session==="Revers")return (best("technical_rating")+best("coach_rating"))/2;
      if(session==="Match play")return (best("tactical_rating")+best("coach_rating"))/2;
      if(session==="Déplacements"||session==="Endurance")return best("fitness_rating");
      return avgStaff;
    };
    const avgFacility=(facilityRows.data??[]).length?(facilityRows.data??[]).reduce((sum:number,x:any)=>sum+Number(x.level||1),0)/(facilityRows.data??[]).length:1;
    const targetScores:any={};
    for(const s of sessions){
      if(["Repos","Récupération"].includes(s))continue;
      const focusMult=careerFocus==="doubles_only"
        ?(["Double","Service","Retour","Match play"].includes(s)?1.12:.96)
        :careerFocus==="singles_only"
          ?(s==="Double"?.30:["Service","Retour","Coup droit","Revers","Match play"].includes(s)?1.08:1)
          :careerFocus==="singles_priority"&&s==="Double"?.90:1;
      targetScores[s]=(targetScores[s]||0)+(.67+sessionStaff(s)/36+avgFacility/12)*focusMult*personalBase*ageMult*conditionMult;
    }
    let minLoad=9,maxLoad=12;
    if(injury!=="Fit"){minLoad=2;maxLoad=6}
    else if(fatigue>=70||fitness<65){minLoad=4;maxLoad=7}
    else if(fatigue>=55||fitness<78){minLoad=6;maxLoad=9}
    else if(playerAge<=22&&fitness>=90&&fatigue<=25){minLoad=10;maxLoad=13}
    const warnings:string[]=[];
    if(load>maxLoad+2)warnings.push("Charge trop élevée : fatigue et blessures vont freiner l’apprentissage.");
    if(load<minLoad-2)warnings.push("Charge très basse : bonne récupération mais progression technique lente.");
    if(!sessions.some((s:string)=>s==="Repos"||s==="Récupération"))warnings.push("Aucune journée de récupération prévue.");
    let hardRun=0,maxHardRun=0;
    for(const s of sessions){hardRun=Number(weights[s]||0)>=2?hardRun+1:0;maxHardRun=Math.max(maxHardRun,hardRun)}
    if(maxHardRun>=4)warnings.push("Quatre séances exigeantes consécutives ou plus : surcharge probable.");
    if(careerFocus==="doubles_only"&&sessions.filter((s:string)=>s==="Double").length<2)warnings.push("Profil double exclusif : ajoute au moins deux séances Double.");
    if(careerFocus==="singles_only"&&sessions.filter((s:string)=>s==="Double").length>1)warnings.push("Profil simple exclusif : trop de volume consacré au Double.");
    const multiplier=personalBase*ageMult*conditionMult*(.84+avgStaff/80+avgFacility/20)*difficultyTrainingMult;
    const risk=injury!=="Fit"?"Élevé":load>maxLoad+2||fatigue>=65?"Élevé":load>maxLoad||fatigue>=50?"Modéré":"Maîtrisé";
    return h({
      ok:true,model:"development-v2",player_name:managed.data.name,age:playerAge,
      current_ability:Number(managed.data.current_ability||0),potential:Number(managed.data.potential||0),
      current_stars:Math.max(.5,Math.min(5,Math.round(Number(managed.data.current_ability||0)/10)/2)),
      potential_stars:Math.max(.5,Math.min(5,Math.round(Number(managed.data.potential||0)/10)/2)),
      load,recommended_load:{min:minLoad,max:maxLoad},risk,multiplier:Number(multiplier.toFixed(3)),
      fatigue,fitness,morale,injury_status:injury,career_focus:careerFocus,difficulty:difficultyKey,is_primary:isPrimary,
      development:{type:String(dev.development_type||"standard"),phase:String(dev.development_context?.phase||((playerAge<=21&&Number(managed.data.potential||0)-Number(managed.data.current_ability||0)>=12)?"prospect":playerAge<Number(dev.peak_age||25)?"developing":playerAge>Number(dev.decline_start_age||30)?"decline":Number(managed.data.current_ability||0)>=Number(managed.data.potential||0)-2?"plateau":"prime")),development_rate:Number(dev.development_rate||10),professionalism:Number(dev.professionalism||10),coachability:Number(dev.coachability||10),resilience:Number(dev.resilience||10),discipline:Number(dev.discipline||10),competitive_drive:Number(dev.competitive_drive||10),confidence_volatility:Number(dev.confidence_volatility||10),burnout_susceptibility:Number(dev.burnout_susceptibility||10),peak_age:Number(dev.peak_age||25),decline_start_age:Number(dev.decline_start_age||30)},
      staff_score:Number(avgStaff.toFixed(1)),facility_score:Number(avgFacility.toFixed(1)),
      targets:Object.entries(targetScores).map(([session,score])=>({session,score:Number(Number(score).toFixed(2))})).sort((a:any,b:any)=>b.score-a.score),
      warnings
    });
  }

  if(path.endsWith("/api/simulate")&&req.method==="POST"){
    let body:any; try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const requestedDate=String(body?.date||"").slice(0,10);
    if(requestedDate&&!/^\d{4}-\d{2}-\d{2}$/.test(requestedDate)) return h({error:"Invalid date"},400);
    const current=await db.from("career_state").select("*").eq("id","demo").maybeSingle();
    if(current.error||!current.data)return h({error:current.error?.message||"Career missing"},500);
    const previousDate=String(current.data.career_date||AGE_REFERENCE_DATE);
    const serverNext=new Date(previousDate+"T12:00:00Z");
    serverNext.setUTCDate(serverNext.getUTCDate()+7);
    const date=serverNext.toISOString().slice(0,10);
    const week=Math.max(1,Number(current.data.week||0)+1);
    await db.from("staff_profiles")
      .update({operational_status:"active",rest_until:null})
      .eq("operational_status","rest")
      .lt("rest_until",date);
    const cs=body?.career_state||{};
    const [staffRows,rosterRows]=await Promise.all([
      db.from("staff").select("weekly_cost,skill,role,profile:staff_profiles(*)"),
      db.from("academy_roster").select("id,weekly_cost,contract_end,status,players(name)").eq("status","active")
    ]);
    const expiredRoster=(rosterRows.data??[]).filter((x:any)=>String(x.contract_end||"9999-12-31")<date);
    const expiringStaffContracts=await db.from("contracts").select("*").eq("subject_type","staff").eq("status","active").lt("end_date",date);
    if(!expiringStaffContracts.error){
      for(const con of expiringStaffContracts.data??[]){
        const member=await db.from("staff").select("*").eq("name",con.subject_name).maybeSingle();
        if(member.data){
          await db.from("staff").delete().eq("id",member.data.id);
          if(member.data.profile_id){
            await Promise.all([
              db.from("staff_profiles").update({market_status:"available",available_from:date}).eq("id",member.data.profile_id),
              db.from("staff_candidates").update({status:"available",interview_status:"not_started"}).eq("profile_id",member.data.profile_id),
              db.from("player_staff_assignments").update({
                active:false,end_date:date,ended_reason:"Fin de contrat"
              }).eq("staff_profile_id",member.data.profile_id).eq("active",true)
            ]);
          }
        }
        await db.from("contracts").update({status:"expired"}).eq("id",con.id);
        await db.from("inbox_items").insert({kind:"staff",title:"Contrat staff terminé",body:con.subject_name+" arrive au terme de son contrat et quitte ton équipe.",action_route:"staff",is_read:false});
      }
    }
    for(const x of expiredRoster){
      await db.from("academy_roster").update({status:"expired"}).eq("id",x.id);
      if(x.players?.name)await db.from("contracts").update({status:"expired"}).eq("subject_type","player").eq("subject_name",x.players.name);
      await db.from("inbox_items").insert({kind:"contract",title:"Contrat joueur expiré",body:(x.players?.name||"Un joueur")+" arrive en fin de contrat.",action_route:"contracts",is_read:false});
    }
    const activeRoster=(rosterRows.data??[]).filter((x:any)=>String(x.contract_end||"9999-12-31")>=date);
    const staffWeekly=(staffRows.data??[]).reduce((s:number,x:any)=>s+Number(x.weekly_cost||0),0);
    const playerWeekly=activeRoster.reduce((s:number,x:any)=>s+Number(x.weekly_cost||0),0);
    const sponsorCycle=await db.rpc("process_sponsor_week",{p_date:date,p_week:week});
    if(sponsorCycle.error)return h({error:sponsorCycle.error.message},500);
    const sponsorWeekly=Number((sponsorCycle.data as any)?.total_paid||0);
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

    const difficultyKey=["discovery","normal","manager","hardcore"].includes(String(body?.difficulty||"normal"))?String(body?.difficulty||"normal"):"normal";
    const difficultyTrainingMult=({discovery:1.12,normal:1,manager:.94,hardcore:.88} as any)[difficultyKey]||1;
    let trainingSessions=Array.isArray(body?.training)?body.training.slice(0,7):[];
    const careerFocus=String(current.data.career_focus||"mixed");
    if(careerFocus==="doubles_only"&&!trainingSessions.length){
      trainingSessions=["Double","Service","Retour","Double","Match play","Récupération","Repos"];
    }else if(careerFocus==="singles_only"&&!trainingSessions.length){
      trainingSessions=["Service","Retour","Coup droit","Revers","Match play","Déplacements","Récupération"];
    }
    const [anthony,facilityRows,progressRows]=await Promise.all([
      getManagedPlayer("id,age,birth_date,current_ability,potential,player_attributes(*)"),
      db.from("facilities").select("level"),
      db.from("user_training_progress").select("*")
    ]);
    let trainingResult:any={improvements:[],capped:[],xp_gains:{},current_ability:Number(current.data.current_ability||56)};
    if(anthony.data){
      const attrs:any=Array.isArray(anthony.data.player_attributes)?anthony.data.player_attributes[0]:anthony.data.player_attributes||{};
      const [devProfile,ceilingRow]=await Promise.all([
        db.from("player_development_profiles")
          .select("development_type,peak_age,decline_start_age,development_rate,professionalism,coachability,resilience,discipline,competitive_drive,coaching_environment,staff_stability,development_context,burnout_susceptibility,confidence_volatility")
          .eq("player_id",anthony.data.id).maybeSingle(),
        db.from("player_attribute_ceilings").select("ceilings").eq("player_id",anthony.data.id).maybeSingle()
      ]);
      const dev:any=devProfile.error?{}:(devProfile.data||{});
      const attrCeilings:any=ceilingRow.error?{}:(ceilingRow.data?.ceilings||{});
      const playerAge=Number(anthony.data.age||24);
      const personalBase=Math.max(.76,Math.min(1.26,
        .72
        +Number(dev.development_rate||10)*.012
        +Number(dev.professionalism||10)*.010
        +Number(dev.coachability||10)*.011
        +Number(dev.staff_stability||8)*.004
      ));
      const ageMult=playerAge<Number(dev.peak_age||25)
        ?1.05
        :playerAge<=Number(dev.decline_start_age||30)
          ?1
          :Math.max(.68,1-(playerAge-Number(dev.decline_start_age||30))*.055);
      const conditionMult=Math.max(.72,Math.min(1.08,
        .88+Number(current.data.fitness||90)/500+Number(current.data.morale||70)/700-Number(current.data.fatigue||20)/550
      ));
      const phase=String(dev.development_context?.phase||"");
      const phaseMult=phase==="prospect"?1.08:phase==="developing"?1.05:phase==="prime"?1:phase==="plateau"?.95:phase==="decline"?.82:1;
      const personalDevMult=personalBase*ageMult*conditionMult*phaseMult;
      const map:any={
        "Service":["serve_power","serve_precision","first_serve_quality","second_serve_quality","serve_variety","serve_spin","serve_consistency","serve_plus_one","timing"],
        "Retour":["return_game","anticipation","return_aggression","return_consistency","counter_skill","reaction","passing_shot","timing","shot_control"],
        "Coup droit":["forehand","forehand_power","forehand_accuracy","forehand_consistency","topspin","shot_control","timing","shot_selection","serve_plus_one"],
        "Revers":["backhand","backhand_power","backhand_accuracy","backhand_consistency","slice","shot_control","timing","passing_shot"],
        "Déplacements":["movement","speed","acceleration","agility","balance","footwork","athleticism","court_positioning","defensive_skill","defense_to_attack"],
        "Endurance":["stamina","strength","athleticism","natural_fitness","recovery","flexibility","work_rate","rally_tolerance","tenacity"],
        "Match play":["tactics","concentration","composure","fighting_spirit","tenacity","decision_making","shot_selection","shot_control","timing","counter_skill","big_points","consistency","killer_instinct","confidence","determination","court_positioning","transition_game","rally_tolerance","defense_to_attack"],
        "Double":["volley","touch","doubles","half_volley","smash","net_positioning","doubles_communication","poaching","anticipation","transition_game","reaction","timing","footwork","serve_consistency"]
      };
      const staffList=(staffRows.data??[]);
      const avgStaff=staffList.length?staffList.reduce((sum:number,x:any)=>sum+Number(x.skill||10),0)/staffList.length:10;
      const avgFacility=(facilityRows.data??[]).length?(facilityRows.data??[]).reduce((sum:number,x:any)=>sum+Number(x.level||1),0)/(facilityRows.data??[]).length:1;
      const profileRows=staffList.map((x:any)=>Array.isArray(x.profile)?x.profile[0]:x.profile).filter(Boolean);
      const staffEfficiency=(p:any)=>{
        if(String(p?.operational_status||"active")==="rest"&&String(p?.rest_until||"9999-12-31")>=date)return .42;
        const burnout=Number(p?.burnout||0),travel=Number(p?.travel_fatigue||0),workload=Number(p?.workload||20),pro=Number(p?.professionalism||10);
        return Math.max(.68,Math.min(1.06,1-burnout*.0032-travel*.0018-Math.max(0,workload-75)*.0015+Math.max(0,pro-14)*.006));
      };
      const best=(key:string,fallback=avgStaff)=>profileRows.length
        ?Math.max(fallback,...profileRows.map((p:any)=>Number(p?.[key]||0)*staffEfficiency(p)))
        :fallback;
      const sessionStaff=(session:string)=>{
        if(session==="Service")return (best("serve_coaching_rating")+best("technical_rating"))/2;
        if(session==="Retour")return (best("return_coaching_rating")+best("tactical_rating"))/2;
        if(session==="Double")return (best("doubles_coaching_rating")+best("tactical_rating")+best("communication_rating"))/3;
        if(session==="Coup droit"||session==="Revers")return (best("technical_rating")+best("coach_rating"))/2;
        if(session==="Match play")return (best("tactical_rating")+best("coach_rating"))/2;
        if(session==="Déplacements"||session==="Endurance")return best("fitness_rating");
        return avgStaff;
      };
      const xp:any={};
      for(const s of trainingSessions){
        const focusMult=careerFocus==="doubles_only"
          ?(["Double","Service","Retour","Match play"].includes(String(s))?1.12:.96)
          :careerFocus==="singles_only"
            ?(String(s)==="Double"?.30:["Service","Retour","Coup droit","Revers","Match play"].includes(String(s))?1.08:1)
            :careerFocus==="singles_priority"&&String(s)==="Double"
              ?.90
              :1;
        const mult=(.67+sessionStaff(String(s))/36+avgFacility/12)*focusMult*personalDevMult*difficultyTrainingMult;
        const targets=map[String(s)]||[];
        const spread=Math.max(.42,Math.min(1,2.4/Math.max(1,targets.length)));
        for(const a of targets)xp[a]=(xp[a]||0)+.52*mult*spread;
      }
      trainingResult.career_focus=careerFocus;
      trainingResult.development_profile={
        type:String(dev.development_type||"standard"),
        coachability:Number(dev.coachability||10),
        professionalism:Number(dev.professionalism||10),
        development_rate:Number(dev.development_rate||10),
        staff_environment:Number(dev.coaching_environment||8),
        phase:phase||null,
        multiplier:Number(personalDevMult.toFixed(3))
      };
      const progressMap=new Map((progressRows.data??[]).map((x:any)=>[x.attribute,Number(x.xp||0)]));
      const attrUpdate:any={};
      let improved=0;
      for(const [a,gain] of Object.entries(xp)){
        let total=Number(progressMap.get(a)||0)+Number(gain);
        const cur=Number(attrs[a]||10);
        const cap=Math.max(cur,Math.min(20,Number(attrCeilings[a]??20)));
        const threshold=(3.35+cur*.24)*
          (playerAge>Number(dev.decline_start_age||30)?1.12:1)*
          (Number(dev.coachability||10)<=8?1.08:1);
        if(total>=threshold&&cur<cap&&Number(anthony.data.current_ability||56)<Number(anthony.data.potential||82)){
          const next=Math.min(cap,cur+1);
          attrUpdate[a]=next;
          total-=threshold;
          trainingResult.improvements.push({attribute:a,from:cur,to:next,ceiling:cap});
          improved++;
        }else if(cur>=cap&&Number(gain)>0){
          trainingResult.capped.push({attribute:a,value:cur,ceiling:cap});
        }
        trainingResult.xp_gains[a]=Number(gain);
        await db.from("user_training_progress").upsert({attribute:a,xp:total,updated_at:new Date().toISOString()},{onConflict:"attribute"});
      }
      if(Object.keys(attrUpdate).length){
        await db.from("player_attributes").update(attrUpdate).eq("player_id",anthony.data.id);
      }
      trainingResult.attribute_improvements=improved;
      trainingResult.current_ability=Number(anthony.data.current_ability||56);
      trainingResult.ca_progression="monthly_development_cycle";
      trainingResult.load=trainingSessions.reduce((sum:number,s:any)=>sum+(["Endurance","Match play","Déplacements"].includes(String(s))?3:["Service","Retour","Coup droit","Revers","Double"].includes(String(s))?2:String(s)==="Récupération"?0:-1),0);
    }

    // Unified circuit engine. Competition-specific adapters still own their
    // draw/match rules, but one SQL orchestrator now owns weekly priority,
    // acceptance, qualifying, conflicts and the cross-circuit integrity audit.
    const unifiedCircuitWindow=await db.rpc("run_unified_circuit_window",{
      p_from_date:previousDate,p_to_date:date
    });
    if(unifiedCircuitWindow.error)return h({error:unifiedCircuitWindow.error.message},500);
    const circuit:any=unifiedCircuitWindow.data||{};
    const circuitResult=(key:string)=>({data:circuit[key]??null,error:null});

    const davisWorldEvents=circuitResult("davis");
    const juniorDavisEvents=circuitResult("junior_davis");
    const unitedCupEvents=circuitResult("united_cup");
    const laverCupPreparation=circuitResult("laver_prepare");
    const laverCupEvents=circuitResult("laver");
    const ncaaTeamPreparation=circuitResult("ncaa_team_prepare");
    const ncaaPriorityEntries=circuitResult("ncaa_priority");
    const worldAcceptanceEvents=circuitResult("world_acceptance");
    const worldAcceptanceReconcile=circuitResult("world_acceptance_reconcile");
    const worldQualifyingEvents=circuitResult("world_qualifying");
    const worldDoublesQualifyingEvents=circuitResult("world_doubles_qualifying");
    const progressiveWorldEvents=circuitResult("progressive_world");
    const worldEvents=circuitResult("world_tournaments");
    const atpFinalsDoublesPreparation=circuitResult("atp_finals_doubles_prepare");
    const atpFinalsDoublesEvents=circuitResult("atp_finals_doubles");
    const ncaaTeamEvents=circuitResult("ncaa_team");
    const juniorQualifyingEvents=circuitResult("junior_qualifying");
    const juniorDoublesPreparation=circuitResult("junior_doubles_prepare");
    const juniorWorldEvents=circuitResult("junior_world");
    const ncaaIndividualEvents=circuitResult("ncaa_individual");
    const ncaaWorldEvents=circuitResult("ncaa_duals");
    const worldDoublesEvents=circuitResult("world_doubles");
    const sim=await db.rpc("simulate_world_week",{p_week:week,p_snapshot_date:date});
    if(sim.error) return h({error:sim.error.message},500);
    const hiddenTraitEvolution=await db.rpc("evolve_player_hidden_traits_from_results",{
      p_from_date:previousDate,
      p_to_date:date
    });
    if(hiddenTraitEvolution.error)return h({error:hiddenTraitEvolution.error.message},500);
    const psychology=await db.rpc("refresh_player_psychology_week",{p_date:date});
    if(psychology.error)return h({error:psychology.error.message},500);

    // Maintain the development pyramids monthly instead of every click/week.
    // This keeps NCAA / ITF / Junior fields full without hammering Disk IO.
    let developmentSupply:any=null;
    let doublesPairRefresh:any=null;
    let staffMarketRefresh:any=null;
    if(week%4===0 || previousDate.slice(0,7)!==date.slice(0,7)){
      const supply=await db.rpc("maintain_development_circuit_supply",{
        p_date:date,
        p_junior_target:1800,
        p_itf_target:3600,
        p_ncaa_target:900
      });
      developmentSupply=supply.error?{error:supply.error.message}:supply.data;

      const staffMarket=await db.rpc("refresh_staff_market",{p_date:date});
      staffMarketRefresh=staffMarket.error?{error:staffMarket.error.message}:staffMarket.data;
      const managedAgentSync=await db.rpc("sync_managed_agent_representation",{p_date:date});
      staffMarketRefresh={
        ...(staffMarketRefresh||{}),
        managedAgent:managedAgentSync.error?{error:managedAgentSync.error.message}:managedAgentSync.data
      };

      if(Number(date.slice(0,4))>2025){
        const careerFocus=await db.rpc("refresh_player_career_focus",{p_date:date});
        const careerLifecycle=await db.rpc("refresh_player_career_lifecycle",{p_date:date});
        const month=Number(date.slice(5,7));
        const quarterly=month===1||month===4||month===7||month===10;
        const physicalMaturation=await db.rpc("progress_player_physical_maturation",{p_date:date});
        const coachingEnvironmentRefresh=await db.rpc("refresh_player_coaching_environment",{p_date:date});
        const playerDevelopment=await db.rpc("progress_player_development_world",{p_date:date});
        const traitEvolution=await db.rpc("evolve_player_development_traits",{p_date:date});
        const aiTraining=await db.rpc("apply_player_ai_training",{p_date:date});
        const aiFocusTraining=await db.rpc("run_ai_training_focus_cycle",{p_date:date});
        const archetypeRefresh=await db.rpc("refresh_player_archetypes",{p_date:date});
        const coachingDevelopment=await db.rpc("apply_player_coaching_development",{p_date:date});
        const coachingEnvironment=await db.rpc("apply_coaching_development_effects",{p_date:date});
        const attributeTrends=await db.rpc("refresh_player_attribute_trends",{p_date:date});
        const ceilingRefresh=await db.rpc("refresh_changed_player_attribute_ceilings",{p_date:date});
        const tacticalPreferences=await db.rpc("refresh_player_tactical_preferences",{p_date:date});
        const roleSuitability=await db.rpc("refresh_player_role_suitability",{p_date:date});
        const tacticalTraits=await db.rpc("refresh_player_tactical_traits",{p_date:date});
        const contextualStars=quarterly
          ?await db.rpc("refresh_player_contextual_stars",{p_date:date})
          :{data:null,error:null};
        const surfacePreferences=quarterly
          ?await db.rpc("refresh_player_surface_preferences",{p_date:date})
          :{data:null,error:null};
        const reputationProfiles=quarterly
          ?await db.rpc("refresh_player_reputation_profiles",{p_date:date})
          :{data:null,error:null};
        const eloBaseline=quarterly
          ?await db.rpc("refresh_player_elo_baseline",{p_date:date})
          :{data:null,error:null};
        const analyticsBase=quarterly
          ?await db.rpc("refresh_player_advanced_metrics",{p_date:date})
          :{data:null,error:null};
        const analyticsExtension=quarterly
          ?await db.rpc("refresh_player_analytics_extensions",{p_date:date})
          :{data:null,error:null};
        const contextTraits=quarterly
          ?await db.rpc("refresh_player_context_traits",{p_date:date})
          :{data:null,error:null};
        developmentSupply={
          ...(developmentSupply||{}),
          physicalMaturation:physicalMaturation.error?{error:physicalMaturation.error.message}:physicalMaturation.data,
          coachingEnvironmentRefresh:coachingEnvironmentRefresh.error?{error:coachingEnvironmentRefresh.error.message}:coachingEnvironmentRefresh.data,
          playerDevelopment:playerDevelopment.error?{error:playerDevelopment.error.message}:playerDevelopment.data,
          traitEvolution:traitEvolution.error?{error:traitEvolution.error.message}:traitEvolution.data,
          aiTraining:aiTraining.error?{error:aiTraining.error.message}:aiTraining.data,
          aiFocusTraining:aiFocusTraining.error?{error:aiFocusTraining.error.message}:aiFocusTraining.data,
          archetypeRefresh:archetypeRefresh.error?{error:archetypeRefresh.error.message}:archetypeRefresh.data,
          coachingDevelopment:coachingDevelopment.error?{error:coachingDevelopment.error.message}:coachingDevelopment.data,
          coachingEnvironment:coachingEnvironment.error?{error:coachingEnvironment.error.message}:coachingEnvironment.data,
          attributeTrends:attributeTrends.error?{error:attributeTrends.error.message}:attributeTrends.data,
          ceilingRefresh:ceilingRefresh.error?{error:ceilingRefresh.error.message}:ceilingRefresh.data,
          tacticalPreferences:tacticalPreferences.error?{error:tacticalPreferences.error.message}:tacticalPreferences.data,
          roleSuitability:roleSuitability.error?{error:roleSuitability.error.message}:roleSuitability.data,
          tacticalTraits:tacticalTraits.error?{error:tacticalTraits.error.message}:tacticalTraits.data,
          contextualStars:contextualStars.error?{error:contextualStars.error.message}:contextualStars.data,
          surfacePreferences:surfacePreferences.error?{error:surfacePreferences.error.message}:surfacePreferences.data,
          reputationProfiles:reputationProfiles.error?{error:reputationProfiles.error.message}:reputationProfiles.data,
          eloBaseline:eloBaseline.error?{error:eloBaseline.error.message}:eloBaseline.data,
          analyticsBase:analyticsBase.error?{error:analyticsBase.error.message}:analyticsBase.data,
          analyticsExtension:analyticsExtension.error?{error:analyticsExtension.error.message}:analyticsExtension.data,
          contextTraits:contextTraits.error?{error:contextTraits.error.message}:contextTraits.data
        };
        const seasonPlans=month===1
          ?await db.rpc("refresh_player_season_plans",{p_date:date})
          :{data:null,error:null};
        const seasonPlanRefine=month===1
          ?await db.rpc("refine_player_season_plans",{p_date:date})
          :{data:null,error:null};
        const seasonPlanPsychology=await db.rpc("adapt_player_season_plans_to_psychology",{p_date:date});
        const seasonPlanRebalance=await db.rpc("rebalance_player_season_plans",{
          p_season:Number(date.slice(0,4)),
          p_reference_date:date
        });
        developmentSupply={
          ...(developmentSupply||{}),
          seasonPlans:seasonPlans.error?{error:seasonPlans.error.message}:seasonPlans.data,
          seasonPlanRefine:seasonPlanRefine.error?{error:seasonPlanRefine.error.message}:seasonPlanRefine.data,
          seasonPlanPsychology:seasonPlanPsychology.error?{error:seasonPlanPsychology.error.message}:seasonPlanPsychology.data,
          seasonPlanRebalance:seasonPlanRebalance.error?{error:seasonPlanRebalance.error.message}:seasonPlanRebalance.data
        };
        const meta=month===1||month===4||month===7||month===10
          ?await db.rpc("ensure_staff_meta_ecosystem",{p_date:date})
          :{data:null,error:null};
        const agents=month===1||month===4||month===7||month===10
          ?await db.rpc("ensure_agent_networks",{p_date:date})
          :{data:null,error:null};
        const agentEvolution=month===1||month===4||month===7||month===10
          ?await db.rpc("evolve_player_agent_networks",{p_date:date})
          :{data:null,error:null};
        const trainingIntake=month===1||month===4||month===7||month===10
          ?await db.rpc("ensure_staff_training_centers",{p_date:date})
          :{data:null,error:null};
        const trainingCenters=await db.rpc("progress_staff_training_centers",{p_date:date});
        const teamStaff=await db.rpc("rotate_college_davis_staff",{p_date:date});
        const coachAcademies=month===1
          ?await db.rpc("ensure_staff_academies",{p_date:date})
          :{data:null,error:null};
        const academyDevelopment=month===1
          ?await db.rpc("apply_staff_academy_development",{p_date:date})
          :{data:null,error:null};
        const evolution=await db.rpc("evolve_staff_ecosystem",{p_date:date});
        const dynamics=await db.rpc("simulate_staff_team_dynamics",{p_date:date});
        const bonds=await db.rpc("refresh_staff_player_bonds",{p_date:date});
        const competition=await db.rpc("refresh_staff_recruitment_competition",{p_date:date});
        const ownStaffOffers=await db.rpc("refresh_user_staff_external_offers",{p_date:date});
        const workload=await db.rpc("refresh_staff_workload",{p_date:date});
        const doublesStaff=await db.rpc("refresh_doubles_staff_assignments",{p_date:date});
        const achievements=await db.rpc("refresh_staff_achievements",{p_date:date});
        const achievementReputation=await db.rpc("apply_staff_achievement_reputation",{p_date:date});
        const staffWorldNews=await db.rpc("publish_staff_world_news",{p_date:date});
        staffMarketRefresh={
          ...(staffMarketRefresh||{}),
          meta:meta.error?{error:meta.error.message}:meta.data,
          agents:agents.error?{error:agents.error.message}:agents.data,
          agentEvolution:agentEvolution.error?{error:agentEvolution.error.message}:agentEvolution.data,
          trainingIntake:trainingIntake.error?{error:trainingIntake.error.message}:trainingIntake.data,
          trainingCenters:trainingCenters.error?{error:trainingCenters.error.message}:trainingCenters.data,
          teamStaff:teamStaff.error?{error:teamStaff.error.message}:teamStaff.data,
          coachAcademies:coachAcademies.error?{error:coachAcademies.error.message}:coachAcademies.data,
          academyDevelopment:academyDevelopment.error?{error:academyDevelopment.error.message}:academyDevelopment.data,
          evolution:evolution.error?{error:evolution.error.message}:evolution.data,
          dynamics:dynamics.error?{error:dynamics.error.message}:dynamics.data,
          bonds:bonds.error?{error:bonds.error.message}:bonds.data,
          competition:competition.error?{error:competition.error.message}:competition.data,
          ownStaffOffers:ownStaffOffers.error?{error:ownStaffOffers.error.message}:ownStaffOffers.data,
          workload:workload.error?{error:workload.error.message}:workload.data,
          doublesStaff:doublesStaff.error?{error:doublesStaff.error.message}:doublesStaff.data,
          achievements:achievements.error?{error:achievements.error.message}:achievements.data,
          achievementReputation:achievementReputation.error?{error:achievementReputation.error.message}:achievementReputation.data,
          staffWorldNews:staffWorldNews.error?{error:staffWorldNews.error.message}:staffWorldNews.data,
          careerFocus:careerFocus.error?{error:careerFocus.error.message}:careerFocus.data,
          careerLifecycle:careerLifecycle.error?{error:careerLifecycle.error.message}:careerLifecycle.data
        };
        const pairs=await db.rpc("refresh_world_doubles_partnerships_fast",{
          p_date:date,
          p_target_pairs:2000
        });
        if(pairs.error){
          doublesPairRefresh={error:pairs.error.message};
        }else{
          const partnerReview=await db.rpc("review_doubles_primary_partners",{p_date:date});
          const primaryPairs=await db.rpc("ensure_doubles_only_primary_partners",{p_date:date});
          const poolTrim=await db.rpc("trim_world_doubles_pair_pool",{
            p_date:date,
            p_target_pairs:2000
          });
          const norm=await db.rpc("normalize_world_doubles_race",{
            p_year:Number(date.slice(0,4)),
            p_date:date
          });
          const [playerDoublesRankings,specialistProgress,social]=await Promise.all([
            db.rpc("refresh_world_doubles_player_rankings",{p_date:date}),
            db.rpc("progress_doubles_specialists",{p_date:date}),
            db.rpc("refresh_social_relationships",{p_date:date})
          ]);
          doublesPairRefresh={
            ...(pairs.data||{}),
            partnerReview:partnerReview.error?{error:partnerReview.error.message}:partnerReview.data,
            primaryCommitments:primaryPairs.error?{error:primaryPairs.error.message}:primaryPairs.data,
            poolTrim:poolTrim.error?{error:poolTrim.error.message}:poolTrim.data,
            normalization:norm.error?{error:norm.error.message}:norm.data,
            playerRankings:playerDoublesRankings.error?{error:playerDoublesRankings.error.message}:playerDoublesRankings.data,
            specialistProgress:specialistProgress.error?{error:specialistProgress.error.message}:specialistProgress.data,
            social:social.error?{error:social.error.message}:social.data
          };
          const managedPartnerReview=await db.rpc("review_managed_doubles_partnership",{p_date:date});
          const partnerOffers=await db.rpc("refresh_managed_doubles_partner_offers",{p_date:date});
          doublesPairRefresh={
            ...(doublesPairRefresh||{}),
            managedPartnerReview:managedPartnerReview.error?{error:managedPartnerReview.error.message}:managedPartnerReview.data,
            partnerOffers:partnerOffers.error?{error:partnerOffers.error.message}:partnerOffers.data
          };
        }
      }
    }

    const academyPlans=body?.player_training&&typeof body.player_training==="object"?body.player_training:{};
    const academyPlayerTraining:any={processed:0,attribute_improvements:0,players:[]};
    const secondaryRoster=await db.from("academy_roster")
      .select("id,player_id,development_focus,squad_role,source_youth_id")
      .eq("status","active").neq("squad_role","Joueur principal").is("source_youth_id",null);
    if(secondaryRoster.error)return h({error:secondaryRoster.error.message},500);

    const focusMap:any={
      "Service":"Service","Retour":"Retour","Coup droit":"Fond de court","Revers":"Fond de court",
      "Déplacements":"Déplacements","Endurance":"Physique","Match play":"Mental","Double":"Double"
    };
    const sessionTargets:any={
      "Service":["serve_power","serve_precision","first_serve_quality","second_serve_quality","serve_variety","serve_spin","serve_consistency","serve_plus_one","timing"],
      "Retour":["return_game","anticipation","return_aggression","return_consistency","counter_skill","reaction","passing_shot","timing","shot_control"],
      "Coup droit":["forehand","forehand_power","forehand_accuracy","forehand_consistency","topspin","shot_control","timing","shot_selection","serve_plus_one"],
      "Revers":["backhand","backhand_power","backhand_accuracy","backhand_consistency","slice","shot_control","timing","passing_shot"],
      "Déplacements":["movement","speed","acceleration","agility","balance","footwork","athleticism","court_positioning","defensive_skill","defense_to_attack"],
      "Endurance":["stamina","strength","athleticism","natural_fitness","recovery","flexibility","work_rate","rally_tolerance","tenacity"],
      "Match play":["tactics","concentration","composure","fighting_spirit","tenacity","decision_making","shot_selection","shot_control","timing","counter_skill","big_points","consistency","killer_instinct","confidence","determination","court_positioning","transition_game","rally_tolerance","defense_to_attack"],
      "Double":["volley","touch","doubles","half_volley","smash","net_positioning","doubles_communication","poaching","anticipation","transition_game","reaction","timing","footwork","serve_consistency"]
    };
    const secondaryStaffProfiles=(staffRows.data??[])
      .map((x:any)=>Array.isArray(x.profile)?x.profile[0]:x.profile)
      .filter(Boolean);
    const secondaryStaffEfficiency=(p:any)=>{
      if(String(p?.operational_status||"active")==="rest"&&String(p?.rest_until||"9999-12-31")>=date)return .42;
      return Math.max(.68,Math.min(1.06,
        1-Number(p?.burnout||0)*.0032-Number(p?.travel_fatigue||0)*.0018
        -Math.max(0,Number(p?.workload||20)-75)*.0015
        +Math.max(0,Number(p?.professionalism||10)-14)*.006
      ));
    };
    const secondaryStaffQuality=secondaryStaffProfiles.length
      ?secondaryStaffProfiles.reduce((sum:number,p:any)=>{
          const raw=Math.max(
            Number(p?.coach_rating||0),Number(p?.technical_rating||0),Number(p?.fitness_rating||0),
            Number(p?.tactical_rating||0),Number(p?.mental_rating||0),Number(p?.doubles_coaching_rating||0)
          );
          return sum+Math.max(8,raw)*secondaryStaffEfficiency(p);
        },0)/secondaryStaffProfiles.length
      :10;
    const secondaryFacilityQuality=(facilityRows.data??[]).length
      ?(facilityRows.data??[]).reduce((sum:number,x:any)=>sum+Number(x.level||1),0)/(facilityRows.data??[]).length
      :1;

    for(const rr of secondaryRoster.data??[]){
      const pid=Number((rr as any).player_id||0);
      const planRaw=(academyPlans as any)[String(pid)];
      const plan=Array.isArray(planRaw)?planRaw.slice(0,7).map(String):[];
      if(!pid||!plan.length)continue;

      const count:any={};
      for(const ss of plan){
        const focus=focusMap[ss];if(focus)count[focus]=(count[focus]||0)+1;
      }
      const focus=(Object.entries(count).sort((a:any,b:any)=>Number(b[1])-Number(a[1]))[0]?.[0] as string)
        ||String((rr as any).development_focus||"Équilibré");
      const rosterFocus=await db.from("academy_roster").update({development_focus:focus}).eq("id",(rr as any).id);
      if(rosterFocus.error)return h({error:rosterFocus.error.message},500);
      await db.from("academy_members").update({development_focus:focus}).eq("player_id",pid).eq("status","active");

      const [playerRow,attrsRow,devRow,ceilRow,progressRowsManaged]=await Promise.all([
        db.from("players").select("id,name,age,birth_date,current_ability,potential,form,fitness,morale,fatigue").eq("id",pid).maybeSingle(),
        db.from("player_attributes").select("*").eq("player_id",pid).maybeSingle(),
        db.from("player_development_profiles")
          .select("development_type,peak_age,decline_start_age,development_rate,professionalism,coachability,staff_stability,development_context,development_phase")
          .eq("player_id",pid).maybeSingle(),
        db.from("player_attribute_ceilings").select("ceilings").eq("player_id",pid).maybeSingle(),
        db.from("managed_player_training_progress").select("attribute,xp").eq("player_id",pid)
      ]);
      const trainingErr=playerRow.error||attrsRow.error||devRow.error||ceilRow.error||progressRowsManaged.error;
      if(trainingErr)return h({error:trainingErr.message},500);
      if(!playerRow.data)continue;

      const p0:any=playerRow.data;
      const attrs:any=attrsRow.data||{};
      const dev:any=devRow.data||{};
      const ceilings:any=ceilRow.data?.ceilings||{};
      const progressMap=new Map((progressRowsManaged.data??[]).map((x:any)=>[String(x.attribute),Number(x.xp||0)]));

      const load=plan.reduce((sum:number,ss:string)=>
        sum+(["Endurance","Match play","Déplacements"].includes(ss)?3:["Service","Retour","Coup droit","Revers","Double"].includes(ss)?2:ss==="Récupération"?0:-1),0);
      const fatigueDelta=Math.max(-3,Math.min(8,Math.round((load-8)/2)));
      const postFatigue=Math.max(0,Math.min(100,Number(p0.fatigue||15)+fatigueDelta));
      const postFitness=Math.max(45,Math.min(100,Number(p0.fitness||90)+(load<=10?1:-2)));
      const postForm=Math.max(35,Math.min(100,Number(p0.form||70)+(load>=7&&load<=12?1:0)));
      const postMorale=Math.max(35,Math.min(100,Number(p0.morale||75)+(load>=6&&load<=12?1:0)));
      const conditionUp=await db.from("players").update({
        fatigue:postFatigue,fitness:postFitness,form:postForm,morale:postMorale
      }).eq("id",pid);
      if(conditionUp.error)return h({error:conditionUp.error.message},500);

      const playerAge=Number(p0.age||ageAt(p0.birth_date,date,20,date)||20);
      const peakAge=Number(dev.peak_age||25),declineAge=Number(dev.decline_start_age||30);
      const personalBase=Math.max(.74,Math.min(1.28,
        .72+Number(dev.development_rate||10)*.012
        +Number(dev.professionalism||10)*.010
        +Number(dev.coachability||10)*.011
        +Number(dev.staff_stability||8)*.004
      ));
      const ageMult=playerAge<peakAge?1.05:playerAge<=declineAge?1:Math.max(.68,1-(playerAge-declineAge)*.055);
      const conditionMult=Math.max(.70,Math.min(1.08,
        .88+postFitness/500+postMorale/700-postFatigue/550
      ));
      const phase=String(dev.development_phase||dev.development_context||"").toLowerCase();
      const phaseMult=phase.includes("prospect")?1.08:phase.includes("develop")?1.05:phase.includes("prime")?1:phase.includes("plateau")?.95:phase.includes("decline")?.82:1;
      const environmentMult=Math.max(.75,Math.min(1.25,
        .67+secondaryStaffQuality/36+secondaryFacilityQuality/12
      ));
      const personalDevMult=personalBase*ageMult*conditionMult*phaseMult*environmentMult*difficultyTrainingMult;

      const xpGain:any={};
      for(const session of plan){
        const targets=sessionTargets[String(session)]||[];
        if(!targets.length)continue;
        const spread=Math.max(.42,Math.min(1,2.4/Math.max(1,targets.length)));
        for(const attr of targets){
          xpGain[attr]=(xpGain[attr]||0)+.52*personalDevMult*spread;
        }
      }

      const attrUpdate:any={};
      const improvements:any[]=[];
      const capped:any[]=[];
      for(const [attr,gainRaw] of Object.entries(xpGain)){
        const gain=Number(gainRaw||0);
        const current=Number(attrs[attr]||10);
        const cap=Math.max(current,Math.min(20,Number(ceilings[attr]??20)));
        const threshold=(3.35+current*.24)
          *(playerAge>declineAge?1.12:1)
          *(Number(dev.coachability||10)<=8?1.08:1);
        let total=Number(progressMap.get(attr)||0)+gain;
        if(total>=threshold&&current<cap&&Number(p0.current_ability||0)<Number(p0.potential||0)){
          const next=Math.min(cap,current+1);
          attrUpdate[attr]=next;
          total=Math.max(0,total-threshold);
          improvements.push({attribute:attr,from:current,to:next,ceiling:cap});
        }else if(current>=cap&&gain>0){
          capped.push({attribute:attr,value:current,ceiling:cap});
        }
        const xpUp=await db.from("managed_player_training_progress").upsert({
          player_id:pid,attribute:attr,xp:total,updated_at:new Date().toISOString()
        },{onConflict:"player_id,attribute"});
        if(xpUp.error)return h({error:xpUp.error.message},500);
      }

      if(Object.keys(attrUpdate).length){
        const au=await db.from("player_attributes").update(attrUpdate).eq("player_id",pid);
        if(au.error)return h({error:au.error.message},500);
      }

      academyPlayerTraining.attribute_improvements+=improvements.length;
      academyPlayerTraining.processed++;
      const reportRow={
        player_id:pid,name:String(p0.name||"Joueur"),focus,load,
        improvement:improvements[0]||null,improvements,capped,
        fatigue:postFatigue,development_multiplier:Number(personalDevMult.toFixed(3))
      };
      academyPlayerTraining.players.push(reportRow);

      const highLoad=load>=13||postFatigue>=65;
      if(improvements.length||highLoad){
        const title=improvements.length
          ?"Progression · "+String(p0.name||"Joueur")
          :"Charge à surveiller · "+String(p0.name||"Joueur");
        const progressText=improvements.length
          ?improvements.slice(0,3).map((x:any)=>String(x.attribute)+" "+String(x.from)+" → "+String(x.to)).join(", ")
          :"";
        const bodyText=improvements.length
          ?String(p0.name||"Le joueur")+" progresse : "+progressText+". Focus de la semaine : "+focus+"."
          :String(p0.name||"Le joueur")+" termine la semaine avec une charge "+String(load)+" et une fatigue estimée à "+String(postFatigue)+". Ajuste son plan si nécessaire.";
        await db.from("inbox_items").insert({
          kind:"training",title,body:bodyText,action_route:"training",game_date:date,
          priority:highLoad?"high":"normal",
          action_type:"open_route",action_label:"Ouvrir son entraînement",
          action_payload:{route:"training",player_id:pid},
          decision_status:"info",related_entity_type:"player",related_entity_id:pid,is_read:false
        });
      }
    }

    if(academyPlayerTraining.processed>0){
      const improved=academyPlayerTraining.players.filter((x:any)=>x.improvement).length;
      const overloaded=academyPlayerTraining.players.filter((x:any)=>Number(x.load||0)>=13||Number(x.fatigue||0)>=65).length;
      const summary=academyPlayerTraining.players
        .map((x:any)=>String(x.name)+": "+String(x.focus)+" · charge "+String(x.load)+(x.improvement?" · progression "+String(x.improvement.attribute):""))
        .join(" | ");
      await db.from("inbox_items").insert({
        kind:"training",
        title:"Rapport entraînement académie · semaine "+String(week),
        body:String(academyPlayerTraining.processed)+" joueur(s) suivis. "+String(improved)+" progression(s) visible(s), "+String(overloaded)+" charge(s) à surveiller. "+summary.slice(0,1400),
        action_route:"training",game_date:date,
        priority:overloaded>0?"high":"normal",
        action_type:"open_route",action_label:"Voir les plans individuels",
        action_payload:{route:"training"},
        decision_status:"info",is_read:false
      });
    }

    const academyDev=await db.rpc("simulate_academy_roster_week",{p_week:week,p_date:date});
    if(academyDev.error)return h({error:academyDev.error.message},500);
    const academyIntake=await db.rpc("academy_refresh_intake",{p_date:date});
    if(academyIntake.error)return h({error:academyIntake.error.message},500);
    const academyStorylines=await db.rpc("academy_weekly_storylines",{p_date:date,p_week:week});
    if(academyStorylines.error)return h({error:academyStorylines.error.message},500);

    // Injury risk is evaluated on the post-match load before weekly recovery.
    // New injuries are then converted into withdrawals before fatigue is reduced.
    const injurySim=await db.rpc("simulate_injuries_week",{p_date:date,p_week:week});
    if(injurySim.error)return h({error:injurySim.error.message},500);

    const forfeitSim=await db.rpc("refresh_tournament_forfeits",{p_date:date});
    if(forfeitSim.error)return h({error:forfeitSim.error.message},500);

    const recoverySim=await db.rpc("apply_world_recovery_week",{p_date:date,p_week:week});
    if(recoverySim.error)return h({error:recoverySim.error.message},500);

    // World matches/injuries/recovery mutate players. Pull the managed player's
    // post-world condition back into career_state before the medical protocol.
    // The career_state trigger then mirrors medical changes back to players.
    const managedConditionSync=await db.rpc("sync_managed_condition_from_player");
    if(managedConditionSync.error)return h({error:managedConditionSync.error.message},500);

    const medicalRoster=await db.from("academy_roster")
      .select("player_id").eq("status","active").not("player_id","is",null);
    if(medicalRoster.error)return h({error:medicalRoster.error.message},500);
    const primaryMedicalId=Number(current.data.managed_player_id||0);
    const medicalPlayerIds=[...new Set([
      primaryMedicalId,
      ...(medicalRoster.data??[]).map((x:any)=>Number(x.player_id||0))
    ].filter(Boolean))];
    const managedMedical:any[]=[];
    for(const pid of medicalPlayerIds){
      const mr=await db.rpc("apply_managed_medical_week",{p_date:date,p_player_id:pid});
      if(mr.error)return h({error:"Suivi médical joueur "+String(pid)+" : "+mr.error.message},500);
      managedMedical.push(mr.data);
    }
    const medicalCost=managedMedical.reduce((sum:number,x:any)=>sum+Number(x?.weekly_cost||0),0);
    const medicalPrimary=managedMedical.find((x:any)=>Number(x?.player_id||0)===primaryMedicalId)||managedMedical[0]||null;
    const medicalRecoveryEffects=await db.rpc("process_recovered_injury_effects",{p_date:date});
    if(medicalRecoveryEffects.error)return h({error:medicalRecoveryEffects.error.message},500);

    const weeklyLedger=await recordFinanceTransactions([
      {transaction_key:"week:"+date+":staff",game_date:date,week,category:"staff_payroll",amount:-staffWeekly,source_type:"weekly_cycle",description:"Salaires du staff"},
      {transaction_key:"week:"+date+":academy",game_date:date,week,category:"academy_payroll",amount:-playerWeekly,source_type:"weekly_cycle",description:"Contrats joueurs académie"},
      {transaction_key:"week:"+date+":medical",game_date:date,week,category:"medical",amount:-medicalCost,source_type:"weekly_cycle",description:"Suivi médical du groupe géré",metadata:{players:managedMedical}}
    ]);
    const scouts=await db.from("scouting_assignments")
      .select("id,region,focus,progress,status,staff_profile_id,staff:staff_profiles!scouting_assignments_staff_profile_id_fkey(id,name,scouting_rating,reputation,regions,professionalism,workload,burnout,travel_fatigue,operational_status,rest_until)");
    if(!scouts.error){
      const staffProfiles=(staffRows.data??[]).map((x:any)=>Array.isArray(x.profile)?x.profile[0]:x.profile).filter(Boolean);
      const scoutEfficiency=(p:any)=>{
        if(String(p?.operational_status||"active")==="rest"&&String(p?.rest_until||"9999-12-31")>=date)return .40;
        return Math.max(.62,Math.min(1.08,
          1-Number(p?.burnout||0)*.0032-Number(p?.travel_fatigue||0)*.0018-Math.max(0,Number(p?.workload||20)-75)*.0015+Math.max(0,Number(p?.professionalism||10)-14)*.006
        ));
      };
      const fallback=staffProfiles.length
        ?staffProfiles.sort((a:any,b:any)=>Number(b.scouting_rating||0)-Number(a.scouting_rating||0))[0]
        :null;
      for(const s of scouts.data??[]){
        if(s.status!=="active")continue;
        const sp:any=Array.isArray((s as any).staff)?(s as any).staff[0]:(s as any).staff||fallback||{};
        const rating=Number(sp.scouting_rating||10);
        const regions=Array.isArray(sp.regions)?sp.regions:[];
        const regionText=String((s as any).region||"");
        const regionBonus=regions.some((r:any)=>regionText.toLowerCase().includes(String(r).toLowerCase()))?2:0;
        const step=Math.max(5,Math.min(20,Math.round(5+(rating+regionBonus)*.58*scoutEfficiency(sp))));
        const np=Math.min(100,Number((s as any).progress||0)+step);
        const quality=Math.max(40,Math.min(98,Math.round(42+rating*2.4*scoutEfficiency(sp)+regionBonus*2)));
        const confidence=Math.max(40,Math.min(98,Math.round(45+rating*2.2*scoutEfficiency(sp)+regionBonus*2)));
        const update=await db.from("scouting_assignments").update({
          progress:np,status:np>=100?"completed":"active",
          confidence,report_quality:quality,last_update:date
        }).eq("id",(s as any).id);
        if(!update.error&&np>=100){
          await db.rpc("complete_scouting_assignment",{p_assignment_id:(s as any).id,p_date:date});
        }
      }
    }
    const [userRank,userDoubleRank]=await Promise.all([
      db.rpc("recalculate_user_ranking",{p_date:date}),
      db.rpc("recalculate_user_doubles_ranking",{p_date:date})
    ]);
    if(userRank.error||userDoubleRank.error)return h({error:(userRank.error||userDoubleRank.error)?.message},500);

    const managedRankingRows:any[]=[];
    const managedRoster=await db.from("academy_roster").select("player_id").eq("status","active").not("player_id","is",null);
    if(managedRoster.error)return h({error:managedRoster.error.message},500);
    const primaryRankState=await db.from("career_state").select("managed_player_id").eq("id","demo").maybeSingle();
    if(primaryRankState.error)return h({error:primaryRankState.error.message},500);
    const primaryRankingId=Number(primaryRankState.data?.managed_player_id||0);
    for(const row of managedRoster.data??[]){
      const pid=Number((row as any).player_id||0);
      if(!pid||pid===primaryRankingId)continue;
      const rr=await db.rpc("recalculate_managed_player_ranking",{p_player_id:pid,p_date:date,p_sync_career:false});
      if(rr.error)return h({error:"Recalcul classement joueur "+String(pid)+" : "+rr.error.message},500);
      managedRankingRows.push(rr.data);
    }
    const sponsorEligibility=await db.rpc("refresh_sponsor_offer_eligibility",{p_date:date});
    if(sponsorEligibility.error)return h({error:sponsorEligibility.error.message},500);
    const board=await db.rpc("update_board_state");
    if(board.error)return h({error:board.error.message},500);
    const managedSeasonPlan=await db.rpc("ensure_managed_season_plan",{p_date:date});
    if(managedSeasonPlan.error)return h({error:managedSeasonPlan.error.message},500);
    const careerInboxSync=await db.rpc("career_sync_actionable_inbox",{p_date:date,p_week:week});
    if(careerInboxSync.error)return h({error:careerInboxSync.error.message},500);
    const operationalInbox=await db.rpc("career_sync_operational_alerts",{p_date:date,p_week:week});
    if(operationalInbox.error)return h({error:operationalInbox.error.message},500);
    const weeklyDigest=await db.rpc("career_publish_weekly_digest",{p_date:date,p_week:week});
    if(weeklyDigest.error)return h({error:weeklyDigest.error.message},500);
    const actionableInbox=careerInboxSync.data;
    const mediaEvent=await db.rpc("career_generate_media_event",{p_date:date});
    if(mediaEvent.error)return h({error:mediaEvent.error.message},500);
    const careerHealth=await db.rpc("career_system_health",{p_date:date});
    if(careerHealth.error)return h({error:careerHealth.error.message},500);
    return h({ok:true,date,week,circuitEngine:{model:circuit.model||'CB-UNIFIED-CIRCUIT-v1',ok:circuit.ok!==false,integrity:circuit.integrity??null},world:sim.data,worldPsychology:psychology.data,hiddenTraitEvolution:hiddenTraitEvolution.data,davisWorldTies:davisWorldEvents.data,unitedCupEvents:unitedCupEvents.data,juniorDavisCup:juniorDavisEvents.data,laverCupPreparation:laverCupPreparation.data,laverCup:laverCupEvents.data,ncaaTeamPreparation:ncaaTeamPreparation.data,ncaaTeamEvents:ncaaTeamEvents.data,ncaaPriorityEntries:ncaaPriorityEntries.data,ncaaIndividualEvents:ncaaIndividualEvents.data,ncaaWorldDuals:ncaaWorldEvents.data,worldAcceptance:worldAcceptanceEvents.data,worldAcceptanceReconcile:worldAcceptanceReconcile.data,worldQualifying:worldQualifyingEvents.data,worldDoublesQualifying:worldDoublesQualifyingEvents.data,progressiveWorldTournaments:progressiveWorldEvents.data,worldTournaments:worldEvents.data,atpFinalsDoublesPreparation:atpFinalsDoublesPreparation.data,atpFinalsDoubles:atpFinalsDoublesEvents.data,juniorQualifyingEvents:juniorQualifyingEvents.data,juniorDoublesPreparation:juniorDoublesPreparation.data,juniorWorldTournaments:juniorWorldEvents.data,worldDoublesTournaments:worldDoublesEvents.data,developmentSupply,doublesPairRefresh,staffMarketRefresh,userRanking:userRank.data,managedPlayerRankings:managedRankingRows,userDoublesRanking:userDoubleRank.data,sponsorEligibility:sponsorEligibility.data,training:trainingResult,academyPlayerTraining,academyDevelopment:academyDev.data,academyIntake:academyIntake.data,academyStorylines:academyStorylines.data,managedSeasonPlan:managedSeasonPlan.data,careerInboxSync:careerInboxSync.data,operationalInbox:operationalInbox.data,weeklyDigest:weeklyDigest.data,actionableInbox,mediaEvent:mediaEvent.data,careerHealth:careerHealth.data,injuries:injurySim.data,forfeits:forfeitSim.data,recovery:recoverySim.data,managedConditionSync:managedConditionSync.data,medical:medicalPrimary,managedMedical,medicalRecoveryEffects:medicalRecoveryEffects.data,board:board.data,weeklyFinance:{staff:staffWeekly,players:playerWeekly,sponsors:sponsorWeekly,sponsor_cycle:sponsorCycle.data,medical:medicalCost,net:weeklyNet-medicalCost,expired_contracts:expiredRoster.length,ledger:weeklyLedger}});
  }

  if(path.endsWith("/api/staff-world")&&req.method==="GET"){
    const q=String(u.searchParams.get("q")||"").trim();
    const role=String(u.searchParams.get("role")||"").trim();
    const country=String(u.searchParams.get("country")||"").trim().toUpperCase();
    const former=String(u.searchParams.get("former")||"Tous").trim();
    const status=String(u.searchParams.get("status")||"Tous").trim();
    const offset=n(u.searchParams.get("offset"),0,0,100000);
    const limit=n(u.searchParams.get("limit"),50,1,100);
    const cs=await db.from("career_state").select("managed_player_id").eq("id","demo").maybeSingle();
    if(cs.error)return h({error:cs.error.message},500);
    const data=await db.rpc("staff_world_search",{
      p_managed_player_id:Number(cs.data?.managed_player_id||0)||null,
      p_q:q,p_role:role,p_country:country,p_former:former,p_status:status,p_offset:offset,p_limit:limit
    });
    if(data.error)return h({error:data.error.message},500);
    return h(data.data||{rows:[],total:0,offset,limit,roles:[],countries:[],agencies:[],academies:[],training_centers:[]});
  }

  if(path.endsWith("/api/staff-profile")&&req.method==="GET"){
    const id=n(u.searchParams.get("id"),0,1,99999999);
    const profile=await db.from("staff_profiles").select("*").eq("id",id).maybeSingle();
    if(profile.error)return h({error:profile.error.message},500);
    if(!profile.data)return h({error:"Profil staff introuvable"},404);

    const [activeAssignments,history,events,agency,licenses,preferences,scopeReputation,peerA,peerB,recommendationsFrom,recommendationsTo,collegeStaff,davisStaff,training,coachAcademy,bonds,careerStats,achievements,awards]=await Promise.all([
      db.from("player_staff_assignments")
        .select("id,role,start_date,end_date,active,verified,affinity,trust,role_fit,satisfaction,team_chemistry,weekly_salary,contract_end,source_label,player:players!player_staff_assignments_player_id_fkey(id,name,country,ranking,game_world_rank,style,photo_url)")
        .eq("staff_profile_id",id).eq("active",true)
        .order("start_date",{ascending:false}).limit(30),
      db.from("player_staff_assignments")
        .select("id,role,start_date,end_date,active,verified,affinity,trust,role_fit,satisfaction,team_chemistry,weekly_salary,contract_end,ended_reason,source_label,player:players!player_staff_assignments_player_id_fkey(id,name,country,ranking,game_world_rank,style,photo_url)")
        .eq("staff_profile_id",id).eq("active",false)
        .order("end_date",{ascending:false}).limit(50),
      db.from("staff_career_events").select("*").eq("staff_profile_id",id).order("event_date",{ascending:false}).limit(50),
      db.from("staff_agency_members").select("*,agency:staff_agencies(*)").eq("staff_profile_id",id).eq("active",true).maybeSingle(),
      db.from("staff_licenses").select("*").eq("staff_profile_id",id).order("license_level",{ascending:false}),
      db.from("staff_preferences").select("*").eq("staff_profile_id",id).maybeSingle(),
      db.from("staff_scope_reputation").select("*").eq("staff_profile_id",id).order("rating",{ascending:false}),
      db.from("staff_peer_relationships").select("*,other:staff_profiles!staff_peer_relationships_staff_b_id_fkey(id,name,primary_role,nationality,reputation)").eq("staff_a_id",id).eq("active",true).order("affinity",{ascending:false}).limit(20),
      db.from("staff_peer_relationships").select("*,other:staff_profiles!staff_peer_relationships_staff_a_id_fkey(id,name,primary_role,nationality,reputation)").eq("staff_b_id",id).eq("active",true).order("affinity",{ascending:false}).limit(20),
      db.from("staff_recommendations").select("*,other:staff_profiles!staff_recommendations_to_staff_id_fkey(id,name,primary_role,nationality,reputation,market_status,specialty,asking_weekly_cost)").eq("from_staff_id",id).eq("active",true).order("strength",{ascending:false}).limit(20),
      db.from("staff_recommendations").select("*,other:staff_profiles!staff_recommendations_from_staff_id_fkey(id,name,primary_role,nationality,reputation,market_status,specialty,asking_weekly_cost)").eq("to_staff_id",id).eq("active",true).order("strength",{ascending:false}).limit(20),
      db.from("college_team_staff").select("*,team:college_teams(*)").eq("staff_profile_id",id).eq("active",true).limit(10),
      db.from("davis_team_staff").select("*").eq("staff_profile_id",id).eq("active",true).limit(10),
      db.from("staff_training_enrollments").select("*,center:staff_training_centers(*)").eq("staff_profile_id",id).order("start_date",{ascending:false}).limit(10),
      db.from("staff_academy_members")
        .select("started_year,graduated_year,development_bonus,academy:staff_academies(*),mentor:staff_profiles!staff_academy_members_mentor_staff_id_fkey(id,name,primary_role,reputation)")
        .eq("staff_profile_id",id).maybeSingle(),
      db.from("staff_player_bonds")
        .select("bond_type,affinity,trust,respect,is_simulated,source_label,formed_date,last_update,player:players!staff_player_bonds_player_id_fkey(id,name,country,ranking,game_world_rank,photo_url,style)")
        .eq("staff_profile_id",id).eq("active",true)
        .order("affinity",{ascending:false}).limit(30),
      db.from("staff_career_stats").select("*").eq("staff_profile_id",id).maybeSingle(),
      db.from("staff_achievements")
        .select("achievement_date,tournament_name,level,event_type,staff_role,achievement_points,player:players!staff_achievements_player_id_fkey(id,name,country,ranking,game_world_rank)")
        .eq("staff_profile_id",id).order("achievement_date",{ascending:false}).limit(40),
      db.from("staff_awards").select("*").eq("staff_profile_id",id).order("season",{ascending:false}).limit(20)
    ]);
    const err=activeAssignments.error||history.error||events.error||agency.error||licenses.error||preferences.error||scopeReputation.error||peerA.error||peerB.error||recommendationsFrom.error||recommendationsTo.error||collegeStaff.error||davisStaff.error||training.error||coachAcademy.error||bonds.error||careerStats.error||achievements.error||awards.error;
    if(err)return h({error:err.message},500);

    let agentClients:any={data:[],count:0,error:null};
    if(/agent/i.test(String(profile.data.primary_role||""))){
      agentClients=await db.from("player_agency_representation")
        .select("player_id,commission_pct,trust,start_date,player:players!player_agency_representation_player_id_fkey(id,name,country,ranking,game_world_rank,photo_url)",{count:"exact"})
        .eq("agent_staff_id",id).eq("active",true)
        .order("trust",{ascending:false})
        .limit(30);
      if(agentClients.error)return h({error:agentClients.error.message},500);
    }

    return h({
      profile:profile.data,
      activeAssignments:activeAssignments.data??[],
      history:history.data??[],
      events:events.data??[],
      agency:agency.data??null,
      licenses:licenses.data??[],
      preferences:preferences.data??null,
      scopeReputation:scopeReputation.data??[],
      peers:[...(peerA.data??[]),...(peerB.data??[])].sort((a:any,b:any)=>Number(b.affinity||0)-Number(a.affinity||0)).slice(0,20),
      recommendations:{from:recommendationsFrom.data??[],to:recommendationsTo.data??[]},
      collegeStaff:collegeStaff.data??[],
      davisStaff:davisStaff.data??[],
      training:training.data??[],
      coachAcademy:coachAcademy.data??null,
      playerBonds:bonds.data??[],
      careerStats:careerStats.data??null,
      achievements:achievements.data??[],
      awards:awards.data??[],
      agentClients:agentClients.data??[],
      agentClientCount:Number(agentClients.count||0)
    });
  }

  if(path.endsWith("/api/career-hub")&&req.method==="GET"){
    const requestedPlayerId=n(u.searchParams.get("player_id"),0,0,99999999);
    const career=await db.from("career_state").select("*").eq("id","demo").maybeSingle();
    if(career.error||!career.data)return h({error:career.error?.message||"Career missing"},500);

    const primaryId=Number(career.data.managed_player_id||0);
    const managedId=Number(requestedPlayerId||primaryId||0);
    if(!managedId)return h({error:"Joueur géré introuvable"},404);
    if(managedId!==primaryId){
      const roster=await db.from("academy_roster").select("id,squad_role").eq("player_id",managedId).eq("status","active").maybeSingle();
      if(roster.error)return h({error:roster.error.message},500);
      if(!roster.data)return h({error:"Ce joueur ne fait pas partie du groupe géré."},403);
    }

    const managedPlayer=await db.from("players")
      .select("id,name,country,ranking,points,doubles_ranking,doubles_points,form,fitness,morale,fatigue,career_focus,age,birth_date,style")
      .eq("id",managedId).maybeSingle();
    if(managedPlayer.error||!managedPlayer.data)return h({error:managedPlayer.error?.message||"Joueur introuvable"},404);

    const year=Number(String(career.data.career_date||AGE_REFERENCE_DATE).slice(0,4));
    const ensuredPlan=await db.rpc("ensure_player_season_plan",{
      p_player_id:managedId,p_date:String(career.data.career_date||AGE_REFERENCE_DATE)
    });
    if(ensuredPlan.error)return h({error:ensuredPlan.error.message},500);

    const [health,integrity,seasonPlan,media,sponsors,board,timeline,relationships,academy,medicalPlan]=await Promise.all([
      db.rpc("career_system_health",{p_date:String(career.data.career_date||AGE_REFERENCE_DATE)}),
      db.rpc("career_os_integrity_audit",{p_date:String(career.data.career_date||AGE_REFERENCE_DATE)}),
      db.from("player_season_plans").select("*").eq("player_id",managedId).eq("season",year).maybeSingle(),
      db.from("media_events").select("*").lte("event_date",career.data.career_date).order("event_date",{ascending:false}).order("id",{ascending:false}).limit(60),
      db.from("sponsor_offers").select("*").order("status",{ascending:true}).order("created_at",{ascending:false}).limit(30),
      db.from("board_objectives").select("*").order("priority",{ascending:true}),
      db.from("career_event_log").select("*").lte("event_date",career.data.career_date).order("event_date",{ascending:false}).order("id",{ascending:false}).limit(100),
      db.from("player_relationships")
        .select("id,player_a_id,player_b_id,relation_type,affinity,trust,respect,closeness,is_simulated,source_label,formed_date,last_update,active,player_a:players!player_relationships_player_a_id_fkey(id,name,country,ranking,doubles_ranking,photo_url),player_b:players!player_relationships_player_b_id_fkey(id,name,country,ranking,doubles_ranking,photo_url)")
        .eq("active",true)
        .or("player_a_id.eq."+managedId+",player_b_id.eq."+managedId)
        .order("affinity",{ascending:false}).limit(40),
      db.from("academies").select("*").eq("id","demo").maybeSingle(),
      db.from("player_medical_plans").select("*").eq("player_id",managedId).maybeSingle()
    ]);
    const err=health.error||integrity.error||seasonPlan.error||media.error||sponsors.error||board.error||timeline.error||relationships.error||academy.error||medicalPlan.error;
    if(err)return h({error:err.message},500);

    const p:any=managedPlayer.data;
    const careerView:any={
      ...career.data,
      managed_player_id:managedId,
      player_name:String(p.name||career.data.player_name||"Joueur"),
      country:String(p.country||career.data.country||"FRA"),
      singles_rank:Number(p.ranking??career.data.singles_rank??9999),
      points:Number(p.points??(managedId===primaryId?career.data.points:0)??0),
      doubles_rank:Number(p.doubles_ranking??career.data.doubles_rank??9999),
      doubles_points:Number(p.doubles_points??(managedId===primaryId?career.data.doubles_points:0)??0),
      form:Number(p.form??career.data.form??70),
      fitness:Number(p.fitness??career.data.fitness??90),
      morale:Number(p.morale??career.data.morale??70),
      fatigue:Number(p.fatigue??career.data.fatigue??15),
      career_focus:String(p.career_focus||(managedId===primaryId?career.data.career_focus:"mixed")||"mixed"),
      age:p.age??career.data.age??null,
      style:p.style??career.data.style??null,
      primary_managed_player_id:primaryId,
      is_primary_managed:managedId===primaryId
    };
    const rels=(relationships.data??[]).map((x:any)=>{
      const other=Number(x.player_a_id)===managedId
        ?(Array.isArray(x.player_b)?x.player_b[0]:x.player_b)
        :(Array.isArray(x.player_a)?x.player_a[0]:x.player_a);
      return {...x,other};
    });

    return h({
      model:"CB-CAREER-HUB-v3",
      player_id:managedId,
      primary_player_id:primaryId,
      health:health.data??null,
      integrity:integrity.data??null,
      career:careerView,
      season_plan:seasonPlan.data??null,
      seasonPlan:seasonPlan.data??null,
      medical_plan:medicalPlan.data??null,
      medicalPlan:medicalPlan.data??null,
      media:media.data??[],
      sponsors:sponsors.data??[],
      board:board.data??[],
      objectives:board.data??[],
      timeline:timeline.data??[],
      events:timeline.data??[],
      relationships:rels,
      academy:academy.data??null
    });
  }

  if(path.endsWith("/api/managed-player-context")&&req.method==="GET"){
    const career=await db.from("career_state").select("managed_player_id,career_date").eq("id","demo").maybeSingle();
    if(career.error||!career.data)return h({error:career.error?.message||"Career missing"},500);
    const primaryId=Number(career.data.managed_player_id||0);
    const requestedId=n(u.searchParams.get("player_id"),primaryId,1,99999999);
    if(!requestedId)return h({error:"Joueur géré introuvable"},404);
    let squadRole="Joueur principal";
    if(requestedId!==primaryId){
      const roster=await db.from("academy_roster").select("squad_role,status").eq("player_id",requestedId).eq("status","active").maybeSingle();
      if(roster.error)return h({error:roster.error.message},500);
      if(!roster.data)return h({error:"Ce joueur ne fait pas partie du groupe géré."},403);
      squadRole=String(roster.data.squad_role||"Joueur académie");
    }
    const season=Number(String(career.data.career_date||AGE_REFERENCE_DATE).slice(0,4));
    const [player,entries,doublesEntries,seasonPlan,injury,loadProfile,medicalPlan]=await Promise.all([
      db.from("players").select("id,name,country,ranking,points,doubles_ranking,doubles_points,age,birth_date,current_ability,potential,form,fitness,morale,fatigue,style,injury_status,career_focus,photo_url").eq("id",requestedId).maybeSingle(),
      db.from("entries")
        .select("id,tournament_id,player_id,status,entry_method,entry_rank,requested_on,withdrawn_on,metadata,updated_at,tournaments(id,name,country,circuit,category,start_date,end_date,qualifying_start_date,qualifying_end_date,main_draw_start_date,qualifying_entry_deadline,main_entry_deadline,singles_entry_deadline,late_entry_deadline)")
        .eq("player_id",requestedId).eq("status","entered").order("requested_on",{ascending:true}),
      db.from("managed_doubles_entries")
        .select("id,owner_id,tournament_id,player_id,partner_id,status,entry_method,entry_phase,combined_rank,protected_combined_rank,projected_cut,requested_on,withdrawn_on,metadata,updated_at,partner:players!managed_doubles_entries_partner_id_fkey(id,name,country,ranking,doubles_ranking),tournaments(id,name,country,circuit,category,start_date,end_date,qualifying_start_date,main_draw_start_date)")
        .eq("owner_id","demo").eq("player_id",requestedId).eq("status","entered").order("requested_on",{ascending:true}),
      db.from("player_season_plans").select("*").eq("player_id",requestedId).eq("season",season).maybeSingle(),
      db.from("injuries").select("*").eq("player_id",requestedId).eq("status","Active").order("started_at",{ascending:false}).limit(1).maybeSingle(),
      db.from("player_training_load_profiles").select("*").eq("player_id",requestedId).order("as_of_date",{ascending:false}).limit(1).maybeSingle(),
      db.from("player_medical_plans").select("*").eq("player_id",requestedId).maybeSingle()
    ]);
    const err=player.error||entries.error||doublesEntries.error||seasonPlan.error||injury.error||loadProfile.error||medicalPlan.error;
    if(err)return h({error:err.message},500);
    if(!player.data)return h({error:"Joueur introuvable"},404);
    return h({
      model:"CB-MANAGED-PLAYER-CONTEXT-v1",
      primary_player_id:primaryId,
      player_id:requestedId,
      is_primary:requestedId===primaryId,
      squad_role:squadRole,
      career_date:String(career.data.career_date||AGE_REFERENCE_DATE),
      player:player.data,
      entries:entries.data??[],
      doubles_entries:doublesEntries.data??[],
      season_plan:seasonPlan.data??null,
      injury:injury.data??null,
      training_load:loadProfile.data??null,
      medical_plan:medicalPlan.data??null
    });
  }

  if(path.endsWith("/api/management")&&req.method==="GET"){
    const [contracts,college,shortlist,sponsors,candidates,partnerships,collegeOffers,collegeState,collegeDuals,davisTies,academyMembers,academyRoster,collegeTeamStaff,davisTeamStaff] = await Promise.all([
      db.from("contracts").select("*").order("end_date"),
      db.from("college_teams").select("*").order("ita_rank"),
      db.from("shortlist").select("*,players(id,name,country,ranking,points,age,potential,current_ability,style)").order("added_at",{ascending:false}).limit(50),
      db.from("sponsor_offers").select("*").order("id"),
      db.from("staff_candidates").select("*,profile:staff_profiles(*)").order("skill",{ascending:false}),
      db.from("doubles_partnerships").select("*,player_a:players!doubles_partnerships_player_a_id_fkey(id,name,country,ranking,doubles_ranking),player_b:players!doubles_partnerships_player_b_id_fkey(id,name,country,ranking,doubles_ranking)").order("id",{ascending:false}).limit(20),
      db.from("college_offers").select("*,team:college_teams(*)").order("scholarship_pct",{ascending:false}),
      db.from("college_career_state").select("*,team:college_teams(*)").eq("id","demo").maybeSingle(),
      db.from("college_duals").select("*,home:college_teams!college_duals_home_team_id_fkey(*),away:college_teams!college_duals_away_team_id_fkey(*)").order("match_date",{ascending:true}).limit(20),
      db.from("davis_ties").select("*,davis_rubbers(*)").order("tie_date",{ascending:true}).limit(40),
      db.from("academy_members").select("*,player:players(id,name,country,ranking,doubles_ranking,age,current_ability,potential,form,fitness,morale,fatigue,style),youth:academy_youth(id,name,country,age,current_ability,potential,style,status),progress:academy_member_progress(*)").eq("status","active").order("id"),
      db.from("academy_roster").select("*,players(id,name,country,ranking,points,doubles_ranking,age,current_ability,potential,form,fitness,morale,fatigue,style,injury_status)").eq("status","active").order("id"),
      db.from("college_team_staff").select("id,team_id,role,start_date,end_date,active,staff:staff_profiles(id,name,nationality,primary_role,reputation,coach_rating,technical_rating,tactical_rating,mental_rating,fitness_rating,medical_rating,scouting_rating,youth_rating,staff_personality,coaching_style)").eq("active",true).order("team_id").order("role"),
      db.from("davis_team_staff").select("id,nation,role,start_date,end_date,active,part_time,staff:staff_profiles(id,name,nationality,primary_role,reputation,coach_rating,technical_rating,tactical_rating,mental_rating,fitness_rating,medical_rating,communication_rating,pressure_handling,staff_personality,coaching_style)").eq("active",true).order("nation").order("role")
    ]);
    const err=contracts.error||college.error||shortlist.error||sponsors.error||candidates.error||partnerships.error||collegeOffers.error||collegeState.error||collegeDuals.error||davisTies.error||academyMembers.error||academyRoster.error||collegeTeamStaff.error||davisTeamStaff.error;
    if(err) return h({error:err.message},500);

    const staffTrainingCenters=await db.from("staff_training_centers")
      .select("*").eq("active",true)
      .order("reputation",{ascending:false}).order("name");
    const userStaffTraining=await db.from("staff_training_enrollments")
      .select("id,staff_profile_id,start_date,expected_end,focus,progress,status,cost,user_managed,center:staff_training_centers(id,name,country,specialty,reputation)")
      .eq("user_managed",true)
      .order("start_date",{ascending:false})
      .limit(30);

    const careerNow=await db.from("career_state").select("managed_player_id,career_date,career_focus,doubles_rank").eq("id","demo").maybeSingle();
    if(careerNow.error)return h({error:careerNow.error.message},500);
    const primaryManagedId=Number(careerNow.data?.managed_player_id||0);
    const requestedManagedId=n(u.searchParams.get("player_id"),0,0,99999999);
    const managedId=Number(requestedManagedId||primaryManagedId||0);
    if(managedId&&managedId!==primaryManagedId){
      const inRoster=(academyRoster.data??[]).some((x:any)=>
        Number(x.player_id||x.players?.id||0)===managedId&&String(x.status||"active")==="active"
      );
      if(!inRoster)return h({error:"Ce joueur ne fait pas partie du groupe géré."},403);
    }

    let managedCollegeState:any=null;
    let managedCollegeOffers:any[]=[];
    let managedCollegeDuals:any[]=[];
    if(managedId){
      const ensured=await db.rpc("ensure_player_college_state",{p_player_id:managedId});
      if(ensured.error)return h({error:ensured.error.message},500);
      const stateId=String((ensured.data as any)?.state_id||(managedId===primaryManagedId?"demo":"player:"+managedId));
      const [stateRes,offersRes]=await Promise.all([
        db.from("college_career_state")
          .select("*,team:college_teams(*)").eq("id",stateId).eq("player_id",managedId).maybeSingle(),
        db.from("college_offers")
          .select("*,team:college_teams(*)").eq("player_id",managedId).order("scholarship_pct",{ascending:false})
      ]);
      if(stateRes.error||offersRes.error)return h({error:(stateRes.error||offersRes.error)?.message},500);
      managedCollegeState=stateRes.data??null;
      managedCollegeOffers=offersRes.data??[];
      const teamId=Number(managedCollegeState?.chosen_team_id||0);
      managedCollegeDuals=teamId
        ?(collegeDuals.data??[]).filter((x:any)=>Number(x.home_team_id||0)===teamId||Number(x.away_team_id||0)===teamId)
        :[];
    }

    const managedDoublesCommitment=managedId
      ?await db.from("player_doubles_commitments")
        .select("season,primary_partner_id,started_at,last_review_date,commitment,affinity,switches,reason,source_label,active,partner:players!player_doubles_commitments_primary_partner_id_fkey(id,name,country,ranking,doubles_ranking,career_focus,current_ability)")
        .eq("player_id",managedId).eq("active",true).maybeSingle()
      :{data:null,error:null};
    const doublesPartnerOffers=managedId
      ?await db.from("doubles_partner_offers")
        .select("id,from_player_id,to_player_id,season,offer_date,response_date,expires_at,direction,status,interest_score,acceptance_threshold,chemistry,compatibility,pair_strength,proposed_commitment,current_partner_id,current_partner_commitment,reason,source_label,from_player:players!doubles_partner_offers_from_player_id_fkey(id,name,country,ranking,doubles_ranking,career_focus,current_ability),to_player:players!doubles_partner_offers_to_player_id_fkey(id,name,country,ranking,doubles_ranking,career_focus,current_ability)")
        .or(`from_player_id.eq.${managedId},to_player_id.eq.${managedId}`)
        .order("offer_date",{ascending:false})
        .limit(30)
      :{data:[],error:null};
    const ownStaff=await db.from("staff").select("id,name,role,profile_id").not("profile_id","is",null);
    const ownProfileIds=[...new Set((ownStaff.data??[]).map((x:any)=>Number(x.profile_id)).filter(Boolean))];
    let ownStaffRelations:any[]=[];
    if(ownProfileIds.length>1){
      const rels=await db.from("staff_peer_relationships")
        .select("*,staff_a:staff_profiles!staff_peer_relationships_staff_a_id_fkey(id,name,primary_role,reputation),staff_b:staff_profiles!staff_peer_relationships_staff_b_id_fkey(id,name,primary_role,reputation)")
        .eq("active",true)
        .in("staff_a_id",ownProfileIds)
        .in("staff_b_id",ownProfileIds)
        .order("conflict_score",{ascending:false});
      if(!rels.error)ownStaffRelations=rels.data??[];
    }
    const ownStaffOffers=await db.from("user_staff_external_offers")
      .select("id,staff_profile_id,competitor_player_id,offered_weekly,offer_date,deadline,status,staff:staff_profiles(id,name,primary_role,reputation,ambition,loyalty),competitor:players!user_staff_external_offers_competitor_player_id_fkey(id,name,country,ranking,game_world_rank)")
      .eq("status","pending")
      .order("deadline",{ascending:true});

    const managedAgency=managedId
      ?await db.from("player_agency_representation")
        .select("start_date,end_date,commission_pct,active,trust,agency:staff_agencies(*),agent:staff_profiles!player_agency_representation_agent_staff_id_fkey(id,name,nationality,primary_role,reputation,negotiation_rating,former_player_status)")
        .eq("player_id",managedId).eq("active",true).maybeSingle()
      :{data:null,error:null};
    const agencyNetwork=await db.rpc("agency_network_overview",{p_limit:12});
    const staffLeaders=await db.rpc("staff_world_leaderboard",{p_limit:20});
    const academyIntakeHistory=await db.from("academy_intake_history")
      .select("id,academy_id,youth_id,intake_year,generated_on,country,initial_ca,potential_floor,potential_ceiling,signed,destination,youth:academy_youth(id,name,country,age,status,pathway_preference)")
      .eq("academy_id","demo").order("intake_year",{ascending:false}).order("id",{ascending:false}).limit(60);
    const academyConfig=await db.from("academies").select("head_of_youth_profile_id").eq("id","demo").maybeSingle();
    const academyHeadId=Number(academyConfig.data?.head_of_youth_profile_id||0);
    const academyHead=academyHeadId
      ?await db.from("staff_profiles")
        .select("id,name,nationality,primary_role,youth_rating,development_rating,communication_rating,reputation,specialty,staff_personality,coaching_style,photo_url")
        .eq("id",academyHeadId).maybeSingle()
      :{data:null,error:null};
    const academyStaffCandidates=await db.from("staff")
      .select("id,name,role,profile_id,profile:staff_profiles(id,name,nationality,primary_role,youth_rating,development_rating,communication_rating,reputation,specialty)")
      .not("profile_id","is",null).order("skill",{ascending:false});
    const financeTransactions=await db.from("finance_transactions")
      .select("id,transaction_key,game_date,week,category,amount,currency,source_type,source_id,description,balance_after,metadata")
      .order("game_date",{ascending:false}).order("id",{ascending:false}).limit(200);

    return h({
      contracts:contracts.data??[],college:college.data??[],shortlist:shortlist.data??[],sponsors:sponsors.data??[],
      candidates:candidates.data??[],partnerships:partnerships.data??[],collegeOffers:managedCollegeOffers,
      collegeState:managedCollegeState,collegeDuals:managedCollegeDuals,davisTies:davisTies.data??[],
      academyMembers:academyMembers.data??[],academyRoster:academyRoster.data??[],
      collegeTeamStaff:collegeTeamStaff.data??[],davisTeamStaff:davisTeamStaff.data??[],
      staffTrainingCenters:staffTrainingCenters.error?[]:(staffTrainingCenters.data??[]),
      userStaffTraining:userStaffTraining.error?[]:(userStaffTraining.data??[]),
      managedPlayerId:managedId,
      primaryManagedPlayerId:primaryManagedId,
      managedAgency:managedAgency.error?null:managedAgency.data,
      agencyNetwork:agencyNetwork.error?[]:(agencyNetwork.data??[]),
      staffLeaders:staffLeaders.error?[]:(staffLeaders.data??[]),
      ownStaffRelations,
      ownStaffOffers:ownStaffOffers.error?[]:(ownStaffOffers.data??[]),
      doublesPartnerOffers:doublesPartnerOffers.error?[]:(doublesPartnerOffers.data??[]),
      managedDoublesCommitment:managedDoublesCommitment.error?null:managedDoublesCommitment.data,
      academyIntakeHistory:academyIntakeHistory.error?[]:(academyIntakeHistory.data??[]),
      academyHead:academyHead.error?null:academyHead.data,
      academyStaffCandidates:academyStaffCandidates.error?[]:(academyStaffCandidates.data??[]),
      financeTransactions:financeTransactions.error?[]:(financeTransactions.data??[])
    });
  }




  if(path.endsWith("/api/ranking-ledger")&&req.method==="GET"){
    const requestedPlayerId=n(u.searchParams.get("player_id"),0,0,99999999);
    const weeks=n(u.searchParams.get("weeks"),18,1,52);
    const career=await db.from("career_state").select("managed_player_id,career_date").eq("id","demo").maybeSingle();
    if(career.error)return h({error:career.error.message},500);
    const primaryId=Number(career.data?.managed_player_id||0);
    const playerId=Number(requestedPlayerId||primaryId||0);
    if(!playerId)return h({error:"Joueur géré introuvable"},404);
    if(playerId!==primaryId){
      const roster=await db.from("academy_roster").select("id").eq("player_id",playerId).eq("status","active").maybeSingle();
      if(roster.error)return h({error:roster.error.message},500);
      if(!roster.data)return h({error:"Ce joueur ne fait pas partie du groupe géré."},403);
    }
    const today=String(u.searchParams.get("date")||career.data?.career_date||AGE_REFERENCE_DATE).slice(0,10);
    const [summary,breakdown,defending,player]=await Promise.all([
      db.rpc("atp_player_ranking_summary",{p_player_id:playerId,p_date:today}),
      db.rpc("atp_player_breakdown",{p_player_id:playerId,p_date:today}),
      db.rpc("atp_points_to_defend",{p_player_id:playerId,p_date:today,p_weeks:weeks}),
      db.from("players").select("id,name,ranking,points,ranking_source,ranking_snapshot_date").eq("id",playerId).maybeSingle()
    ]);
    const err=summary.error||breakdown.error||defending.error||player.error;
    if(err)return h({error:err.message},500);
    if(!player.data)return h({error:"Joueur introuvable"},404);
    const sum=Array.isArray(summary.data)?summary.data[0]:summary.data||{};
    const all=(breakdown.data??[]).map((x:any)=>({...x,expiry_date:x.drop_date,active:String(x.drop_date)>=today}));
    const counting=all.filter((x:any)=>x.counting);
    const nonCounting=all.filter((x:any)=>!x.counting);
    const weekly=defending.data??[];
    const nextWeek=weekly.find((x:any)=>Number(x.points_to_defend||0)>0)||null;
    return h({
      date:today,player_id:playerId,player_name:player.data.name,rank:player.data.ranking,
      total:Number(sum?.total_points??player.data.points??0),
      ranking_source:player.data.ranking_source,ranking_snapshot_date:player.data.ranking_snapshot_date,
      mandatory_tiebreak_points:Number(sum?.mandatory_tiebreak_points||0),
      events_played:Number(sum?.events_played||0),counting_events:Number(sum?.counting_events||0),
      result_vector:sum?.result_vector??[],
      active:counting,counting,non_counting:nonCounting,breakdown:all,
      defending:weekly,next_defense:nextWeek,weeks,
      model:"ATP 2026 · 52 semaines glissantes · portefeuille événementiel · max 3 remplacements M1000",
      historical_note:"Le snapshot 01/12/2025 est réconcilié avec le total ATP officiel; les résultats historiques identifiables conservent leur valeur tournoi."
    });
  }

  if(path.endsWith("/api/play-tournament")&&req.method==="POST"){
    let body:any;try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const tid=n(body?.tournament_id,0,1,99999999);
    const requestedPlayerId=n(body?.player_id,0,0,99999999);
    const tactics=body?.tactics||{};
    const tacticAgg=n(tactics.aggression,58,1,100),tacticRisk=n(tactics.risk,52,1,100),tacticNet=n(tactics.net,28,1,100);
    const returnPos=String(tactics.returnPos||"Neutre");
    const [tour,career,forfeits,userStaff]=await Promise.all([
      db.from("tournaments").select("*").eq("id",tid).maybeSingle(),
      db.from("career_state").select("*").eq("id","demo").maybeSingle(),
      db.from("tournament_forfeits").select("player_id,reason").eq("tournament_id",tid),
      db.from("staff").select("role,profile:staff_profiles(id,tactical_rating,mental_rating,pressure_handling,scouting_rating,communication_rating,professionalism,workload,burnout,travel_fatigue,energy,operational_status,rest_until)")
    ]);
    if(tour.error||career.error||forfeits.error||userStaff.error)return h({error:(tour.error||career.error||forfeits.error||userStaff.error)?.message},500);
    if(!tour.data||!career.data)return h({error:"Tournament or career missing"},404);

    const primaryPlayPlayerId=Number(career.data.managed_player_id||0);
    const managedId=Number(requestedPlayerId||primaryPlayPlayerId||0);
    if(!managedId)return h({error:"Joueur géré introuvable"},404);
    if(managedId!==primaryPlayPlayerId){
      const roster=await db.from("academy_roster").select("id").eq("player_id",managedId).eq("status","active").maybeSingle();
      if(roster.error)return h({error:roster.error.message},500);
      if(!roster.data)return h({error:"Ce joueur ne fait pas partie du groupe géré."},403);
    }
    const [managedPlayer,oldRun,wc,activeInjury]=await Promise.all([
      db.from("players")
        .select("id,name,country,ranking,junior_ranking,birth_date,points,current_ability,form,fitness,fatigue,morale,handedness,career_focus,injury_status,player_attributes(*)")
        .eq("id",managedId).maybeSingle(),
      db.from("tournament_runs").select("id,managed_player_id").eq("tournament_id",tid).eq("managed_player_id",managedId).order("played_at",{ascending:false}).limit(1).maybeSingle(),
      db.from("wildcard_requests").select("*").eq("tournament_id",tid).eq("player_id",managedId).maybeSingle(),
      db.from("injuries").select("id,injury_type,severity,started_at,expected_return,status").eq("player_id",managedId).in("status",["active","Active"]).order("started_at",{ascending:false}).limit(1).maybeSingle()
    ]);
    if(managedPlayer.error||oldRun.error||wc.error||activeInjury.error)return h({error:(managedPlayer.error||oldRun.error||wc.error||activeInjury.error)?.message},500);
    if(!managedPlayer.data)return h({error:"Joueur géré introuvable"},404);
    let existingRun:any=oldRun.data??null;
    if(!existingRun&&managedId===primaryPlayPlayerId){
      const legacyRun=await db.from("tournament_runs").select("id,managed_player_id").eq("tournament_id",tid).is("managed_player_id",null).order("played_at",{ascending:false}).limit(1).maybeSingle();
      if(legacyRun.error)return h({error:legacyRun.error.message},500);
      existingRun=legacyRun.data??null;
    }
    if(existingRun)return h({error:"Ce joueur a déjà joué ce tournoi dans cette sauvegarde.",run_id:existingRun.id,player_id:managedId},409);

    const t:any=tour.data;
    const isPrimaryManaged=managedId===primaryPlayPlayerId;
    const c:any={...career.data};
    c.player_name=String(managedPlayer.data.name||c.player_name||"Joueur");
    c.country=String(managedPlayer.data.country||c.country||"FRA");
    c.singles_rank=Number(managedPlayer.data.ranking??c.singles_rank??2001);
    c.points=Number(managedPlayer.data.points??c.points??0);
    c.current_ability=Number(managedPlayer.data.current_ability??c.current_ability??55);
    c.form=Number(managedPlayer.data.form??c.form??70);
    c.fitness=Number(managedPlayer.data.fitness??c.fitness??90);
    c.fatigue=Number(managedPlayer.data.fatigue??c.fatigue??15);
    c.morale=Number(managedPlayer.data.morale??c.morale??75);
    c.career_focus=String(managedPlayer.data.career_focus||c.career_focus||"mixed");
    const specialTeamEvent=specialTeamEventMeta(t);
    if(specialTeamEvent)return h({
      error:"Cette compétition se joue par équipes et par sélection. Le tableau individuel standard est désactivé.",
      team_event:specialTeamEvent,registration_mode:t.registration_mode||null
    },409);
    const mainDrawSizeConfigured=Math.max(8,Math.min(128,Number(t.singles_draw_size||t.draw_size||32)));
    const formatRuleRes=await db.from("tournament_format_rules")
      .select("*")
      .eq("circuit",String(t.circuit||""))
      .eq("category",String(t.category||""))
      .eq("main_draw_size",mainDrawSizeConfigured)
      .maybeSingle();
    if(formatRuleRes.error)return h({error:formatRuleRes.error.message},500);
    const formatRule:any=formatRuleRes.data||(String(t.circuit||"")==="Junior"?juniorTournamentFormatRule(t):null);
    if(String(c.career_focus||"mixed")==="doubles_only"){
      return h({
        error:"Orientation Double exclusivement : ce joueur ne participe plus aux tableaux de simple.",
        career_focus:"doubles_only",
        doubles_only:true
      },409);
    }
    const managedGameDate=String(c.career_date||AGE_REFERENCE_DATE);
    if(activeInjury.data&&(activeInjury.data.expected_return==null||String(activeInjury.data.expected_return)>=managedGameDate)){
      return h({
        error:"Ce joueur est indisponible pour blessure.",
        player_id:managedId,
        injury:activeInjury.data,
        injury_status:String(managedPlayer.data.injury_status||"Blessé")
      },409);
    }
    const frozenCircuit=["ATP","Challenger","ITF"].includes(String(t.circuit||""));
    let frozenEntryMode:string|null=null;
    let frozenEntryPhase:string|null=null;
    let frozenEntryStatus:any=null;

    if(frozenCircuit){
      const mainStart=String(t.main_draw_start_date||t.start_date||managedGameDate);
      const hasQualifying=Number(t.qualifying_draw_size||0)>0&&Boolean(t.qualifying_start_date);
      const qualifyingStart=String(t.qualifying_start_date||mainStart);
      const earliestPlayable=hasQualifying?qualifyingStart:mainStart;

      const persisted=await db.from("entries")
        .select("id,status,entry_method,entry_rank,requested_on,withdrawn_on,metadata")
        .eq("tournament_id",tid)
        .eq("player_id",managedId)
        .order("id",{ascending:false})
        .limit(1)
        .maybeSingle();
      if(persisted.error)return h({error:persisted.error.message},500);

      let managedPathways:any={pathway:{eligible:false,reason:"no_pathway"},special_exempt:{eligible:false},performance_bye:{eligible:false}};
      try{managedPathways=await managedTournamentPathwayBundle(tid,managedId)}
      catch(e){return h({error:String((e as any)?.message||e)},500)}
      const livePathway:any=managedPathways.pathway||{eligible:false};

      if(persisted.data?.status==="withdrawn"){
        return h({
          error:"Tu t’es retiré de ce tournoi.",
          entry_status:"withdrawn",
          withdrawn_on:persisted.data.withdrawn_on||null
        },409);
      }

      if(managedGameDate<earliestPlayable){
        return h({
          error:"Le tournoi n’a pas encore commencé dans ta carrière.",
          career_date:managedGameDate,
          qualifying_start:hasQualifying?qualifyingStart:null,
          main_draw_start:mainStart,
          next_playable_date:earliestPlayable,
          entry_status:persisted.data?.status||null
        },409);
      }

      // Defensive preparation: normally the weekly world engine has already frozen
      // these lists. If a manual play call reaches the start date first, build the
      // same authoritative lists before deciding whether the managed player can play.
      const mainStateBefore=await db.from("world_tournament_acceptance_states")
        .select("tournament_id")
        .eq("tournament_id",tid)
        .maybeSingle();
      if(mainStateBefore.error)return h({error:mainStateBefore.error.message},500);
      if(!mainStateBefore.data){
        const prepMain=await db.rpc("prepare_world_tournament_acceptance_list",{
          p_tournament_id:tid,
          p_frozen_on:String(t.main_entry_deadline||t.singles_entry_deadline||t.deadline||managedGameDate)
        });
        if(prepMain.error)return h({error:prepMain.error.message},500);
      }
      const refreshMain=await db.rpc("refresh_world_tournament_acceptance_list",{
        p_tournament_id:tid,p_date:managedGameDate
      });
      if(refreshMain.error)return h({error:refreshMain.error.message},500);

      if(hasQualifying){
        const qStateBefore=await db.from("world_qualifying_acceptance_states")
          .select("tournament_id")
          .eq("tournament_id",tid)
          .maybeSingle();
        if(qStateBefore.error)return h({error:qStateBefore.error.message},500);
        if(!qStateBefore.data){
          const prepQ=await db.rpc("prepare_world_qualifying_acceptance_list",{
            p_tournament_id:tid,
            p_snapshot_on:String(t.qualifying_entry_deadline||t.freeze_deadline||t.qualifying_signin_date||managedGameDate)
          });
          if(prepQ.error)return h({error:prepQ.error.message},500);
        }
        const refreshQ=await db.rpc("refresh_world_qualifying_acceptance_list",{
          p_tournament_id:tid,p_date:managedGameDate
        });
        if(refreshQ.error)return h({error:refreshQ.error.message},500);
      }

      const [mainEntry,qEntry,llEntry,mainState,qState]=await Promise.all([
        db.from("world_tournament_acceptance_entries")
          .select("status,entry_method,acceptance_order,effective_rank,promoted_on,withdrawn_on,withdrawal_phase,withdrawal_reason")
          .eq("tournament_id",tid).eq("player_id",managedId).maybeSingle(),
        db.from("world_qualifying_acceptance_entries")
          .select("status,entry_method,acceptance_order,effective_rank,promoted_on,withdrawn_on,withdrawal_phase,withdrawal_reason")
          .eq("tournament_id",tid).eq("player_id",managedId).maybeSingle(),
        db.from("world_tournament_lucky_losers")
          .select("selected,ll_order,loss_round_code,ranking_at_seeding")
          .eq("tournament_id",tid).eq("player_id",managedId).eq("selected",true).maybeSingle(),
        db.from("world_tournament_acceptance_states").select("status,frozen_on").eq("tournament_id",tid).maybeSingle(),
        db.from("world_qualifying_acceptance_states").select("status,created_on,movement_closes_on,last_refreshed_on").eq("tournament_id",tid).maybeSingle()
      ]);
      const frozenErr=mainEntry.error||qEntry.error||llEntry.error||mainState.error||qState.error;
      if(frozenErr)return h({error:frozenErr.message},500);

      const me:any=mainEntry.data;
      const qe:any=qEntry.data;
      const ll:any=llEntry.data;

      if(ll?.selected===true){
        if(managedGameDate<mainStart){
          return h({
            error:"Lucky Loser sélectionné, mais le tableau principal n’a pas encore commencé.",
            entry_status:"lucky_loser",
            main_draw_start:mainStart,
            career_date:managedGameDate
          },409);
        }
        frozenEntryMode="lucky_loser";
        frozenEntryPhase="main";
        frozenEntryStatus=ll;
      }else if(me&&["accepted","promoted"].includes(String(me.status))){
        if(managedGameDate<mainStart){
          return h({
            error:"Tu es accepté dans le tableau principal. Il n’a pas encore commencé.",
            entry_status:me.status,
            acceptance_order:me.acceptance_order,
            main_draw_start:mainStart,
            career_date:managedGameDate
          },409);
        }
        frozenEntryMode=me.status==="promoted"
          ?"alternate"
          :(String(me.entry_method)==="protected"?"protected":"direct");
        frozenEntryPhase="main";
        frozenEntryStatus=me;
      }else if(qe&&["accepted","promoted"].includes(String(qe.status))){
        if(managedGameDate<qualifyingStart){
          return h({
            error:"Tu es accepté en qualifications. Elles n’ont pas encore commencé.",
            entry_status:qe.status,
            acceptance_order:qe.acceptance_order,
            qualifying_start:qualifyingStart,
            career_date:managedGameDate
          },409);
        }
        const frozenQMethod=String(qe.entry_method||"qualifying");
        frozenEntryMode=frozenQMethod==="protected_qualifying"||frozenQMethod.endsWith("_qualifying")
          ?frozenQMethod
          :"qualifying";
        frozenEntryPhase="qualifying";
        frozenEntryStatus=qe;
      }else if(persisted.data?.status==="entered"&&livePathway?.eligible===true){
        const pathwayMode=String(livePathway.mode||"");
        const pathwayQualifying=pathwayMode.endsWith("_qualifying");
        const pathwayStart=pathwayQualifying?qualifyingStart:mainStart;
        if(managedGameDate<pathwayStart){
          return h({
            error:pathwayQualifying
              ?"Passerelle validée vers les qualifications, mais elles n’ont pas encore commencé."
              :"Passerelle validée vers le tableau principal, mais il n’a pas encore commencé.",
            entry_status:"pathway_accepted",
            entry_method:pathwayMode,
            pathway_status:livePathway,
            next_playable_date:pathwayStart,
            career_date:managedGameDate
          },409);
        }
        frozenEntryMode=pathwayMode;
        frozenEntryPhase=pathwayQualifying?"qualifying":"main";
        frozenEntryStatus=livePathway;
      }else if(qe?.status==="alternate"||me?.status==="alternate"){
        return h({
          error:qe?.status==="alternate"
            ?"Tu es encore sur la liste des alternates des qualifications."
            :"Tu es encore sur la liste des alternates du tableau principal.",
          entry_status:"alternate",
          qualifying_alternate_order:qe?.status==="alternate"?Number(qe.acceptance_order||0):null,
          main_alternate_order:me?.status==="alternate"?Number(me.acceptance_order||0):null,
          pathway_status:livePathway,
          career_date:managedGameDate
        },409);
      }else if(me?.status==="withdrawn"||qe?.status==="withdrawn"){
        const w=me?.status==="withdrawn"?me:qe;
        return h({
          error:"Ton inscription n’est plus active sur la liste figée.",
          entry_status:"withdrawn",
          withdrawal_reason:w?.withdrawal_reason||null,
          withdrawn_on:w?.withdrawn_on||null
        },409);
      }else if((mainState.data||qState.data)&&wc.data?.status!=="accepted"){
        return h({
          error:"Tu n’es pas dans la liste d’acceptation de ce tournoi.",
          entry_status:"not_accepted",
          main_acceptance_frozen:Boolean(mainState.data),
          qualifying_acceptance_frozen:Boolean(qState.data),
          pathway_status:livePathway,
          requires_persisted_entry:livePathway?.eligible===true&&persisted.data?.status!=="entered"
        },409);
      }
    }
    const staffProfiles=(userStaff.data??[]).map((x:any)=>Array.isArray(x.profile)?x.profile[0]:x.profile).filter(Boolean);
    const matchStaffEfficiency=(p:any)=>{
      if(String(p?.operational_status||"active")==="rest"&&String(p?.rest_until||"9999-12-31")>=String(c.career_date||AGE_REFERENCE_DATE))return .42;
      return Math.max(.68,Math.min(1.06,
        1-Number(p?.burnout||0)*.0032-Number(p?.travel_fatigue||0)*.0018-Math.max(0,Number(p?.workload||20)-75)*.0015+Math.max(0,Number(p?.professionalism||10)-14)*.006
      ));
    };
    const bestStaff=(key:string)=>staffProfiles.length?Math.max(10,...staffProfiles.map((p:any)=>Number(p?.[key]||0)*matchStaffEfficiency(p))):10;

    const staffLinks=await db.from("player_staff_assignments")
      .select("staff_profile_id,role_fit,satisfaction,team_chemistry")
      .eq("player_id",managedId).eq("active",true);
    let staffSynergy=70,staffSatisfaction=70,staffRoleFit=70,staffConflict=0;
    if(!staffLinks.error&&staffLinks.data?.length){
      staffSynergy=(staffLinks.data??[]).reduce((sum:number,x:any)=>sum+Number(x.team_chemistry||70),0)/(staffLinks.data??[]).length;
      staffSatisfaction=(staffLinks.data??[]).reduce((sum:number,x:any)=>sum+Number(x.satisfaction||70),0)/(staffLinks.data??[]).length;
      staffRoleFit=(staffLinks.data??[]).reduce((sum:number,x:any)=>sum+Number(x.role_fit||70),0)/(staffLinks.data??[]).length;
      const ids=[...new Set((staffLinks.data??[]).map((x:any)=>Number(x.staff_profile_id)).filter(Boolean))];
      if(ids.length>1){
        const rel=await db.from("staff_peer_relationships")
          .select("conflict_score").eq("active",true)
          .in("staff_a_id",ids).in("staff_b_id",ids);
        if(!rel.error&&rel.data?.length){
          staffConflict=(rel.data??[]).reduce((sum:number,x:any)=>sum+Number(x.conflict_score||0),0)/(rel.data??[]).length;
        }
      }
    }

    const rawStaffBonus=
      Math.max(0,bestStaff("tactical_rating")-10)*.085
      +Math.max(0,bestStaff("mental_rating")-10)*.045
      +Math.max(0,bestStaff("pressure_handling")-10)*.035
      +Math.max(0,bestStaff("scouting_rating")-10)*.025;
    const synergyMult=.72+(staffSynergy/100)*.20+(staffSatisfaction/100)*.08+(staffRoleFit/100)*.08;
    const staffConflictPenalty=Math.max(0,staffConflict-35)*.012;
    const staffMatchBonus=Math.max(-.8,Math.min(2.8,rawStaffBonus*synergyMult-staffConflictPenalty));
    const isJuniorSingles=String(t.circuit||"")==="Junior";
    const isJuniorFinals=isJuniorSingles&&/Junior Finals/i.test(String(t.category||""))&&!/Double/i.test(String(t.category||""));
    const isAtpSinglesFinals=String(t.circuit||"")==="ATP"&&/ATP Finals/i.test(String(t.category||""))&&!/Next Gen/i.test(String(t.category||""))&&Boolean(t.singles);
    const isSinglesFinals=isJuniorFinals||isAtpSinglesFinals;
    let finalsRaceRows:any[]=[];
    let rank=Number(c.singles_rank||9999);
    if(isJuniorSingles&&!isJuniorFinals){
      rank=Number(managedPlayer.data.junior_ranking||9999);
      const juniorAge=ageAt(managedPlayer.data.birth_date,String(t.start_date||c.career_date||AGE_REFERENCE_DATE),null,null);
      if(juniorAge!=null&&(juniorAge<13||juniorAge>18)){
        return h({
          error:"Âge non éligible au circuit Junior : il faut avoir au moins 13 ans et rester éligible jusqu’à l’année des 18 ans.",
          age:juniorAge,junior_locked:true
        },409);
      }
    }
    if(isJuniorFinals){
      const race=await db.rpc("junior_race_for_date",{p_date:String(c.career_date||AGE_REFERENCE_DATE)});
      if(race.error)return h({error:race.error.message},500);
      finalsRaceRows=(race.data??[]).slice(0,8);
      const own=finalsRaceRows.find((x:any)=>Number(x.id)===managedId);
      if(!own)return h({
        error:"Non qualifié pour les Junior Finals : il faut terminer dans le Top 8 de la Race Junior.",
        finals_locked:true,race_required:8
      },409);
      rank=Number(own.junior_race_ranking||9999);
      finalsRaceRows=finalsRaceRows.map((x:any)=>({...x,finals_rank:Number(x.junior_race_ranking||9999)}));
    }else if(isAtpSinglesFinals){
      const race=await db.from("players")
        .select("id,name,country,race_ranking,race_points,current_ability,form,fitness,fatigue,player_attributes(*)")
        .not("race_ranking","is",null)
        .or(`race_snapshot_date.is.null,race_snapshot_date.lte.${String(c.career_date||AGE_REFERENCE_DATE)}`)
        .or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*")
        .order("race_ranking",{ascending:true}).limit(8);
      if(race.error)return h({error:race.error.message},500);
      finalsRaceRows=(race.data??[]).map((x:any)=>({...x,finals_rank:Number(x.race_ranking||9999)}));
      const own=finalsRaceRows.find((x:any)=>Number(x.id)===managedId);
      if(!own)return h({
        error:"Non qualifié pour les ATP Finals : il faut terminer dans le Top 8 de la Race ATP.",
        finals_locked:true,race_required:8
      },409);
      rank=Number(own.race_ranking||9999);
    }
    let direct=isSinglesFinals?8:Number(t.direct_cut??t.projected_direct_cut??0);
    let qual=isSinglesFinals?8:Number(t.qual_cut??t.projected_qual_cut??0);
    let entryProjectionModel=t.direct_cut!=null||t.qual_cut!=null?"official_cut":"stored_projection";
    let entryRankingDate:string|null=null;
    let entryRank=rank;
    let protectedRankingInfo:any=null;
    let protectedEntryMode:string|null=null;
    let protectedRankingUse:any=null;
    let qualifyingCandidateIdsForRun=new Set<number>();
    const structuredJuniorEntry=isJuniorSingles&&!isJuniorFinals&&direct>0&&qual>direct&&Number(formatRule?.qualifier_count||0)>0;
    if(structuredJuniorEntry)entryProjectionModel="junior_rank_projection";
    if(!isSinglesFinals&&!isJuniorSingles){
      const entrySnapshot=await db.rpc("player_event_eligibility",{
        p_player_id:managedId,p_tournament_id:tid,p_entry_method:"direct"
      });
      if(entrySnapshot.error)return h({error:entrySnapshot.error.message},500);
      if(Number(entrySnapshot.data?.ranking)>0)entryRank=Number(entrySnapshot.data.ranking);
      entryRankingDate=entrySnapshot.data?.ranking_date?String(entrySnapshot.data.ranking_date):null;

      const prStatus=await db.rpc("player_entry_protection_status",{
        p_player_id:managedId,p_event_type:"singles",p_tournament_id:tid
      });
      if(prStatus.error)return h({error:prStatus.error.message},500);
      protectedRankingInfo=prStatus.data||null;

      const qDraw=Math.max(0,Number(t.qualifying_draw_size??formatRule?.qualifying_draw_size??0));
      const qSlots=Math.max(0,Number(formatRule?.qualifier_count||0));
      const wcSlots=Math.max(0,Number(formatRule?.wildcard_count||0));
      const directSlots=Math.max(0,mainDrawSizeConfigured-qSlots-wcSlots);
      const [directField,qualField]=await Promise.all([
        db.rpc("tournament_candidate_player_ids",{p_tournament_id:tid,p_entry_method:"direct",p_limit:Math.max(96,directSlots+80)}),
        qDraw?db.rpc("tournament_candidate_player_ids",{p_tournament_id:tid,p_entry_method:"qualifying",p_limit:Math.max(160,qDraw+120)}):Promise.resolve({data:[],error:null} as any)
      ]);
      if(directField.error||qualField.error)return h({error:(directField.error||qualField.error)?.message},500);
      const blockedForEntry=new Set((forfeits.data??[]).map((x:any)=>Number(x.player_id)));
      const directRows=(directField.data??[])
        .filter((x:any)=>!blockedForEntry.has(Number(x.player_id)))
        .slice(0,directSlots);
      const directIds=new Set(directRows.map((x:any)=>Number(x.player_id)));
      const qualRows=(qualField.data??[])
        .filter((x:any)=>!blockedForEntry.has(Number(x.player_id))&&!directIds.has(Number(x.player_id)))
        .slice(0,qDraw);
      qualifyingCandidateIdsForRun=new Set(qualRows.map((x:any)=>Number(x.player_id)).filter(Boolean));
      const projected=projectedTournamentCuts(
        t,
        directRows.map((x:any)=>({ranking:Number(x.effective_rank||0),entry_method:"direct"})),
        qualRows.map((x:any)=>({ranking:Number(x.effective_rank||0),entry_method:"qualifying"}))
      );
      if(t.direct_cut==null&&Number(projected.projected_direct_cut)>0)direct=Number(projected.projected_direct_cut);
      if(t.qual_cut==null&&Number(projected.projected_qual_cut)>0)qual=Number(projected.projected_qual_cut);
      entryProjectionModel=String(projected.projected_cut_model||entryProjectionModel);
    }
    const wildcardGranted=!isSinglesFinals&&wc.data?.status==="accepted";

    if(!frozenEntryMode&&!isSinglesFinals&&!isJuniorSingles&&!wildcardGranted&&protectedRankingInfo?.available===true){
      const prRank=Number(protectedRankingInfo.protected_rank||0);
      if(prRank>0&&prRank<entryRank){
        if(direct&&entryRank>direct&&prRank<=direct){
          protectedEntryMode="protected";
          entryRank=prRank;
        }else if(qual&&entryRank>qual&&prRank<=qual){
          protectedEntryMode="protected_qualifying";
          entryRank=prRank;
        }
      }
    }

    let specialExempt=frozenEntryMode==="special_exempt";
    let specialExemptInfo:any=specialExempt?frozenEntryStatus:null;
    if(!frozenEntryMode&&!isSinglesFinals&&!isJuniorSingles&&direct&&entryRank>direct&&!wildcardGranted&&!protectedEntryMode){
      const se=await db.rpc("player_special_exempt_status",{p_player_id:managedId,p_target_tournament_id:tid});
      if(se.error)return h({error:se.error.message},500);
      specialExempt=Boolean(se.data?.eligible);
      specialExemptInfo=se.data||null;
    }

    const alternateEligible=!frozenEntryMode&&!isSinglesFinals&&!isJuniorSingles&&!specialExempt&&!protectedEntryMode&&direct&&qual&&entryRank>qual&&entryRank<=qual+50;
    if(!frozenEntryMode&&direct&&qual&&entryRank>qual&&!wildcardGranted&&!alternateEligible&&!specialExempt&&!protectedEntryMode){
      return h({
        error:"Classement insuffisant. Demande une wild card.",
        entry_deadline:t.singles_entry_deadline,
        qualifying_start:t.qualifying_start_date
      },409);
    }

    let alternateEntered=frozenEntryMode==="alternate";
    if(!frozenEntryMode&&alternateEligible&&!wildcardGranted){
      const gap=Math.max(1,entryRank-qual);
      const needed=Math.max(1,Math.ceil(gap/10));
      const availableSpots=(forfeits.data??[]).length;
      if(availableSpots<needed)return h({error:"Pas assez de forfaits pour remonter depuis la liste alternate.",alternate:true,forfeits:availableSpots},409);
      alternateEntered=true;
    }

    const entryMode=frozenEntryMode??(isSinglesFinals?"direct":isJuniorSingles?(structuredJuniorEntry?(wildcardGranted?"wildcard":direct&&rank<=direct?"direct":"qualifying"):"junior"):specialExempt?"special_exempt":wildcardGranted?"wildcard":protectedEntryMode??(alternateEntered?"alternate":(direct&&entryRank<=direct?"direct":"qualifying")));

    if(!isSinglesFinals&&!isJuniorSingles){
      const eligibilityMode=specialExempt?"direct":entryMode;
      const eligible=frozenEntryMode
        ?{data:{eligible:true,reason:"frozen_acceptance",entry_method:entryMode},error:null}
        :await db.rpc("player_event_eligibility",{
            p_player_id:managedId,p_tournament_id:tid,p_entry_method:eligibilityMode
          });
      if(eligible.error)return h({error:eligible.error.message},500);
      if(eligible.data?.eligible===false){
        const reason=String(eligible.data?.reason||"ineligible");
        const labels:any={
          atp_advanced_entry_top500_required:"Entrée avancée ATP refusée : le joueur doit être classé dans le Top 500 pour entrer directement ou en qualifications ATP Tour.",
          challenger_175_125_direct_top500_required:"Entrée directe refusée : en Challenger 175/125, l'advance entry est réservée aux joueurs Top 500. Les joueurs au-delà peuvent viser les qualifications, une wild card ou l'alternate list.",
          itf_play_down_top200:"Classement trop élevé : les joueurs ATP 1-200 ne peuvent pas disputer un M15/M25.",
          ch50_top150_no_direct_or_qualifying:"Classement trop élevé : les joueurs ATP 1-150 ne peuvent pas entrer normalement dans un Challenger 50.",
          ch50_top50_prohibited:"Les joueurs ATP 1-50 ne peuvent pas disputer un Challenger 50, même avec wild card.",
          ch50_wc_51_100_home_nation_only:"Pour un joueur classé 51-100, la wild card Challenger 50 est limitée à un joueur de la nation hôte.",
          ch75_top50_prohibited:"Les joueurs du Top 50 ne peuvent pas disputer un Challenger 75.",
          ch75_11_50_prohibited:"Les joueurs ATP 11-50 ne peuvent pas disputer un Challenger 75.",
          challenger_top10_prohibited:"Les joueurs ATP 1-10 ne peuvent pas disputer un Challenger 75/100/125.",
          challenger_11_50_wildcard_only:"Un joueur ATP 11-50 ne peut entrer en Challenger 100/125 que via une wild card ATP approuvée (ou WC de qualifs lorsqu'elle est autorisée)."
        };
        return h({error:labels[reason]||"Joueur non éligible à ce tournoi selon le règlement du circuit.",entry_rule:eligible.data},409);
      }

      const scheduleMode=entryMode==="protected_qualifying"||entryMode.endsWith("_qualifying")
        ?"qualifying"
        :entryMode==="protected"||[
            "special_exempt","late_entry","junior_reserved",
            "nextgen_accelerator","junior_accelerator","college_accelerator"
          ].includes(entryMode)
          ?"direct"
          :entryMode;
      const schedule=await db.rpc("managed_tournament_schedule_status",{
        p_target_tournament_id:tid,p_entry_mode:scheduleMode,p_player_id:managedId
      });
      if(schedule.error)return h({error:schedule.error.message},500);
      if(schedule.data?.available===false){
        return h({
          error:"Conflit de calendrier : ce tournoi chevauche un engagement déjà joué dans la sauvegarde.",
          schedule_conflict:schedule.data,
          special_exempt:specialExemptInfo
        },409);
      }
    }else if(!isSinglesFinals&&isJuniorSingles){
      const schedule=await db.rpc("managed_tournament_schedule_status",{
        p_target_tournament_id:tid,p_entry_mode:entryMode,p_player_id:managedId
      });
      if(schedule.error)return h({error:schedule.error.message},500);
      if(schedule.data?.available===false){
        return h({
          error:"Conflit de calendrier : ce tournoi junior chevauche un engagement déjà joué dans la sauvegarde.",
          schedule_conflict:schedule.data
        },409);
      }
    }
    const drawSize=isSinglesFinals?8:mainDrawSizeConfigured;
    let playersRes:any;
    const candidateRankOrder=new Map<number,number>();
    if(isSinglesFinals){
      const ids=finalsRaceRows.map((x:any)=>Number(x.id)).filter(Boolean);
      playersRes=ids.length
        ?await db.from("players")
          .select("id,name,country,ranking,points,current_ability,form,fitness,fatigue,morale,handedness,career_focus,player_attributes(*)")
          .in("id",ids)
        :{data:[],error:null};
    }else if(isJuniorSingles){
      playersRes=await db.from("players")
        .select("id,name,country,ranking,junior_ranking,points,current_ability,form,fitness,fatigue,morale,handedness,career_focus,birth_date,player_attributes(*)")
        .not("junior_ranking","is",null)
        .or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*")
        .order("junior_ranking",{ascending:true})
        .limit(Math.min(300,Math.max(drawSize+80,120)));
    }else{
      const wanted=Math.min(1000,Math.max(drawSize+Number(t.qualifying_draw_size||0)+120,220));
      const candidateIds=await db.rpc("tournament_candidate_player_ids",{p_tournament_id:tid,p_entry_method:"candidate",p_limit:wanted});
      if(candidateIds.error)return h({error:candidateIds.error.message},500);
      const ids=(candidateIds.data??[]).map((x:any)=>{const id=Number(x.player_id);candidateRankOrder.set(id,Number(x.effective_rank||999999));return id;}).filter(Boolean);
      playersRes=ids.length
        ?await db.from("players")
          .select("id,name,country,ranking,points,current_ability,form,fitness,fatigue,morale,handedness,career_focus,player_attributes(*)")
          .in("id",ids)
        :{data:[],error:null};
    }
    if(playersRes.error)return h({error:playersRes.error.message},500);
    const blockedIds=new Set((forfeits.data??[]).map((x:any)=>Number(x.player_id)));
    const raceOrder=new Map(finalsRaceRows.map((x:any)=>[Number(x.id),Number(x.finals_rank??x.junior_race_ranking??x.race_ranking??9999)]));
    const pool:any[]=(playersRes.data??[])
      .filter((p:any)=>!blockedIds.has(Number(p.id))&&Number(p.id)!==managedId)
      .map((p:any)=>({...p,ranking:isSinglesFinals?(raceOrder.get(Number(p.id))??9999):isJuniorSingles?Number(p.junior_ranking||999999):(candidateRankOrder.get(Number(p.id))??Number(p.ranking||999999)),player_attributes:Array.isArray(p.player_attributes)?p.player_attributes[0]:p.player_attributes}))
      .sort((a:any,b:any)=>Number(a.ranking||999999)-Number(b.ranking||999999)||Number(b.current_ability||0)-Number(a.current_ability||0));
    if(structuredJuniorEntry){
      const qDraw=Math.max(0,Number(t.qualifying_draw_size??formatRule?.qualifying_draw_size??0));
      qualifyingCandidateIdsForRun=new Set(
        pool
          .filter((p:any)=>Number(p.ranking||999999)>Number(direct)&&Number(p.ranking||999999)<=Number(qual))
          .slice(0,qDraw)
          .map((p:any)=>Number(p.id))
          .filter(Boolean)
      );
    }
    const surface=String(t.surface||"Dur");
    const surfaceNorm=surface.toLowerCase();
    const indoor=Boolean(t.indoor)||String(t.environment||"").toLowerCase()==="indoor";
    const isClay=/terre|clay/.test(surfaceNorm);
    const isGrass=/gazon|grass/.test(surfaceNorm);
    const isCarpet=/carpet|moquette/.test(surfaceNorm);
    const surfKey=isClay?"clay_affinity":isGrass?"grass_affinity":"hard_affinity";
    const courtSpeed=Number(t.court_speed||(isClay?.68:isGrass?1.15:isCarpet?(indoor?1.22:1.10):indoor?1.18:1.0));
    const bestOf=String(t.circuit||"")==="ATP"&&/Grand Chelem|Grand Slam/i.test(String(t.category||t.level||""))?5:3;
    const managedAttrs:any=Array.isArray(managedPlayer.data.player_attributes)?managedPlayer.data.player_attributes[0]:managedPlayer.data.player_attributes||{};
    const user:any={id:managedId,name:String(c.player_name||managedPlayer.data.name||"Joueur"),ranking:rank,current_ability:Number(c.current_ability||managedPlayer.data.current_ability||56),form:Number(c.form||managedPlayer.data.form||72),fitness:Number(c.fitness||managedPlayer.data.fitness||91),fatigue:Number(c.fatigue||managedPlayer.data.fatigue||18),morale:Number(c.morale||managedPlayer.data.morale||72),handedness:String(managedPlayer.data.handedness||""),career_focus:String(c.career_focus||managedPlayer.data.career_focus||"mixed"),player_attributes:managedAttrs,isUser:true};

    const participantIds=[...new Set([managedId,...pool.map((p:any)=>Number(p.id)).filter(Boolean)])];
    const [dynamicRows,eloRows,advancedRows,surfaceRows,contextRows,tacticalRows,developmentRows,h2hRows]=await Promise.all([
      db.from("player_dynamic_ratings").select("*").in("player_id",participantIds),
      db.from("player_elo_ratings").select("*").in("player_id",participantIds),
      db.from("player_advanced_metrics").select("*").in("player_id",participantIds),
      db.from("player_surface_preferences").select("*").in("player_id",participantIds),
      db.from("player_context_traits").select("*").in("player_id",participantIds),
      db.from("player_tactical_preferences").select("*").in("player_id",participantIds),
      db.from("player_development_profiles").select("*").in("player_id",participantIds),
      participantIds.length>1
        ?db.from("player_h2h_records").select("*").in("player_a_id",participantIds).in("player_b_id",participantIds).limit(5000)
        :Promise.resolve({data:[],error:null})
    ]);
    const analyticsError=dynamicRows.error||eloRows.error||advancedRows.error||surfaceRows.error||contextRows.error||tacticalRows.error||developmentRows.error||h2hRows.error;
    if(analyticsError)return h({error:analyticsError.message},500);

    const dynBy=new Map((dynamicRows.data??[]).map((x:any)=>[Number(x.player_id),x]));
    const eloBy=new Map((eloRows.data??[]).map((x:any)=>[Number(x.player_id),x]));
    const advBy=new Map((advancedRows.data??[]).map((x:any)=>[Number(x.player_id),x]));
    const surfaceBy=new Map((surfaceRows.data??[]).map((x:any)=>[Number(x.player_id),x]));
    const contextBy=new Map((contextRows.data??[]).map((x:any)=>[Number(x.player_id),x]));
    const tacticalBy=new Map((tacticalRows.data??[]).map((x:any)=>[Number(x.player_id),x]));
    const developmentBy=new Map((developmentRows.data??[]).map((x:any)=>[Number(x.player_id),x]));
    const h2hBy=new Map((h2hRows.data??[]).map((x:any)=>[Math.min(Number(x.player_a_id),Number(x.player_b_id))+"|"+Math.max(Number(x.player_a_id),Number(x.player_b_id)),x]));
    const participantById=new Map<number,any>([[Number(user.id),user],...pool.map((p:any)=>[Number(p.id),p] as [number,any])]);

    const strength=(p:any)=>{
      const aa=p.player_attributes||{};
      const d:any=dynBy.get(Number(p.id))||{};
      const liveElo:any=eloBy.get(Number(p.id))||{};
      const elo=isClay?Number(liveElo.clay_elo??d.clay_elo??1500)
        :isGrass?Number(liveElo.grass_elo??d.grass_elo??1500)
        :indoor?Number(liveElo.indoor_elo??liveElo.hard_elo??d.hard_elo??1500)
        :Number(liveElo.hard_elo??d.hard_elo??1500);
      return elo/22+Number(d.service_rating||50)*.08+Number(d.return_rating||50)*.08+
        Number(d.pressure_rating||50)*.04+Number(d.tactical_rating||50)*.04+
        Number(aa?.[surfKey]||10)*.20+Number(p.form||70)*.035-Number(p.fatigue||20)*.025;
    };

    const matchupModel=(a:any,b:any)=>{
      const aid=Number(a.id),bid=Number(b.id);
      const aa=a.player_attributes||{},ab=b.player_attributes||{};
      const da:any=dynBy.get(aid)||{},dbb:any=dynBy.get(bid)||{};
      const ea:any=eloBy.get(aid)||{},eb:any=eloBy.get(bid)||{};
      const ma:any=advBy.get(aid)||{},mb:any=advBy.get(bid)||{};
      const sa:any=surfaceBy.get(aid)||{},sb:any=surfaceBy.get(bid)||{};
      const ca:any=contextBy.get(aid)||{},cb:any=contextBy.get(bid)||{};
      const dpa:any=developmentBy.get(aid)||{},dpb:any=developmentBy.get(bid)||{};
      const storedTa:any=tacticalBy.get(aid)||{},storedTb:any=tacticalBy.get(bid)||{};
      const ta:any=a.isUser?{...storedTa,aggression_bias:Math.max(1,Math.min(20,Math.round(tacticAgg/5))),risk_tolerance:Math.max(1,Math.min(20,Math.round(tacticRisk/5))),net_frequency:Math.max(1,Math.min(20,Math.round(tacticNet/5))),return_position:returnPos}:storedTa;
      const tb:any=b.isUser?{...storedTb,aggression_bias:Math.max(1,Math.min(20,Math.round(tacticAgg/5))),risk_tolerance:Math.max(1,Math.min(20,Math.round(tacticRisk/5))),net_frequency:Math.max(1,Math.min(20,Math.round(tacticNet/5))),return_position:returnPos}:storedTb;
      const hrow:any=h2hBy.get(Math.min(aid,bid)+"|"+Math.max(aid,bid));

      const surfaceElo=(d:any,er:any)=>{
        const overall=Number(er.overall_elo??d.overall_elo??1500);
        const specific=isClay?Number(er.clay_elo??d.clay_elo??overall)
          :isGrass?Number(er.grass_elo??d.grass_elo??overall)
          :indoor?Number(er.indoor_elo??er.hard_elo??d.hard_elo??overall)
          :Number(er.hard_elo??d.hard_elo??overall);
        return overall*.50+specific*.50;
      };
      const aElo=surfaceElo(da,ea),bElo=surfaceElo(dbb,eb);
      const eloProb=1/(1+Math.pow(10,(bElo-aElo)/400));

      const serviceReturn=
        ((Number(da.service_rating||50)-Number(dbb.return_rating||50))-(Number(dbb.service_rating||50)-Number(da.return_rating||50)))/100+
        ((Number(aa.first_serve_quality??aa.serve_precision??10)+Number(aa.second_serve_quality??aa.serve_precision??10)+Number(aa.serve_plus_one??aa.forehand??10))-
         (Number(ab.first_serve_quality??ab.serve_precision??10)+Number(ab.second_serve_quality??ab.serve_precision??10)+Number(ab.serve_plus_one??ab.forehand??10)))/180+
        ((Number(aa.return_consistency??aa.return_game??10)+Number(aa.return_aggression??aa.return_game??10))-
         (Number(ab.return_consistency??ab.return_game??10)+Number(ab.return_aggression??ab.return_game??10)))/150+
        ((Number(aa.serve_spin||10)+Number(aa.serve_consistency||10))-(Number(ab.serve_spin||10)+Number(ab.serve_consistency||10)))/260+
        (Number(aa.counter_skill||10)-Number(ab.counter_skill||10))/150;

      const mental=
        ((Number(da.pressure_rating||50)+Number(da.tactical_rating||50))-(Number(dbb.pressure_rating||50)+Number(dbb.tactical_rating||50)))/200+
        ((Number(aa.decision_making??aa.tactics??10)+Number(aa.shot_selection??aa.tactics??10)+Number(aa.consistency??aa.concentration??10)+Number(aa.big_points??aa.composure??10))-
         (Number(ab.decision_making??ab.tactics??10)+Number(ab.shot_selection??ab.tactics??10)+Number(ab.consistency??ab.concentration??10)+Number(ab.big_points??ab.composure??10)))/240+
        ((Number(aa.shot_control||10)+Number(aa.timing||10)+Number(aa.tenacity||10))-
         (Number(ab.shot_control||10)+Number(ab.timing||10)+Number(ab.tenacity||10)))/360;

      const physical=
        ((Number(da.athletic_rating||50)+Number(a.fitness||90)-Number(a.fatigue||20)*.55+Number(aa.natural_fitness??aa.stamina??10)*1.4+Number(aa.recovery||10)*.8+Number(aa.rally_tolerance??aa.stamina??10)*.8)-
         (Number(dbb.athletic_rating||50)+Number(b.fitness||90)-Number(b.fatigue||20)*.55+Number(ab.natural_fitness??ab.stamina??10)*1.4+Number(ab.recovery||10)*.8+Number(ab.rally_tolerance??ab.stamina??10)*.8))/230+
        ((Number(aa.footwork||10)+Number(aa.athleticism||10))-(Number(ab.footwork||10)+Number(ab.athleticism||10)))/220;

      const surfaceFit=(Number(aa?.[surfKey]||10)-Number(ab?.[surfKey]||10))/20;
      const paceFit=(-Math.abs(courtSpeed-Number(sa.preferred_court_speed||1))/Math.max(.12,Number(sa.pace_tolerance||.25))
        +Math.abs(courtSpeed-Number(sb.preferred_court_speed||1))/Math.max(.12,Number(sb.pace_tolerance||.25)))*.11;

      const handed=String(a.handedness||"").toLowerCase()!==String(b.handedness||"").toLowerCase()
        ?((Number(ca.lefty_handling||10)+Number(aa.adaptability||10)+Number(aa.backhand_accuracy||10)+Number(aa.return_consistency||10))
          -(Number(cb.lefty_handling||10)+Number(ab.adaptability||10)+Number(ab.backhand_accuracy||10)+Number(ab.return_consistency||10)))/360
        :0;

      const styleMatch=handed+
        (Number(ma.rally_1_3_win_pct??ma.rally_0_4_win_pct??50)-Number(mb.rally_1_3_win_pct??mb.rally_0_4_win_pct??50))*.0035+
        (Number(ma.rally_10plus_win_pct??ma.rally_9plus_win_pct??50)-Number(mb.rally_10plus_win_pct??mb.rally_9plus_win_pct??50))*.002+
        (Number(ma.return_depth_score||60)-Number(mb.return_depth_score||60))*.0013+
        (Number(ma.serve_impact||0)-Number(mb.serve_impact||0))*.0018;

      const tacticalFit=
        ((Number(ta.net_frequency||10)-10)*(Number(aa.volley||10)+Number(aa.net_positioning||10)-Number(ab.passing_shot??ab.return_game??10)-Number(ab.reaction??ab.anticipation??10))/520+
         (Number(ta.aggression_bias||10)-Number(tb.defense_to_attack_bias||10))*(Number(aa.forehand_power??aa.forehand??10)+Number(aa.serve_plus_one??aa.forehand??10)-20)/600+
         (Number(ta.rally_length_preference||10)-10)*(Number(aa.rally_tolerance??aa.stamina??10)+Number(aa.consistency??aa.concentration??10)-Number(ab.rally_tolerance??ab.stamina??10)-Number(ab.consistency??ab.concentration??10))/520+
         (Number(ta.drop_shot_frequency||10)-10)*(Number(aa.drop_shot??aa.touch??10)+Number(aa.decision_making??aa.tactics??10)-Number(ab.reaction??ab.anticipation??10)-Number(ab.movement||10))/650+
         (Number(ta.defense_to_attack_bias||10)-Number(tb.aggression_bias||10))*(Number(aa.defense_to_attack??aa.tactics??10)+Number(aa.passing_shot??aa.return_game??10)-20)/620)
        -
        ((Number(tb.net_frequency||10)-10)*(Number(ab.volley||10)+Number(ab.net_positioning||10)-Number(aa.passing_shot??aa.return_game??10)-Number(aa.reaction??aa.anticipation??10))/520+
         (Number(tb.aggression_bias||10)-Number(ta.defense_to_attack_bias||10))*(Number(ab.forehand_power??ab.forehand??10)+Number(ab.serve_plus_one??ab.forehand??10)-20)/600);

      let contextFit=((Number(ca.tiebreak_skill||10)+Number(ca.deciding_set_skill||10)+Number(ca.comeback_mentality||10)+Number(ca.front_runner||10))-
        (Number(cb.tiebreak_skill||10)+Number(cb.deciding_set_skill||10)+Number(cb.comeback_mentality||10)+Number(cb.front_runner||10)))/320;
      if(indoor)contextFit+=(Number(ca.indoor_affinity||10)-Number(cb.indoor_affinity||10))/100;

      const bigMatchFit=((Number(ca.big_stage||10)+Number(dpa.important_matches||10)+Number(dpa.pressure||10))-
        (Number(cb.big_stage||10)+Number(dpb.important_matches||10)+Number(dpb.pressure||10)))/220;

      const bo5Fit=bestOf>=5
        ?((Number(ca.best_of_five||10)+Number(aa.stamina||10)+Number(aa.recovery||10)+Number(dpa.resilience||10)+Number(dpa.important_matches||10))-
          (Number(cb.best_of_five||10)+Number(ab.stamina||10)+Number(ab.recovery||10)+Number(dpb.resilience||10)+Number(dpb.important_matches||10)))/360
        :0;

      const confidenceFit=(Number(a.morale||70)-Number(b.morale||70))*.0032+
        (Number(aa.confidence||10)-Number(ab.confidence||10))*.010+
        (Number(dpa.temperament||10)-Number(dpb.temperament||10))*.006;

      const extServeA=Number(aa.serve_power||10)*.58+Number(aa.serve_variety||10)*.42;
      const extServeB=Number(ab.serve_power||10)*.58+Number(ab.serve_variety||10)*.42;
      const extGroundA=Number(aa.forehand_accuracy||10)*.18+Number(aa.backhand_power||10)*.18+
        Number(aa.forehand_consistency||10)*.18+Number(aa.backhand_consistency||10)*.18+
        Number(aa.topspin||10)*.11+Number(aa.slice||10)*.08+Number(aa.patience||10)*.09;
      const extGroundB=Number(ab.forehand_accuracy||10)*.18+Number(ab.backhand_power||10)*.18+
        Number(ab.forehand_consistency||10)*.18+Number(ab.backhand_consistency||10)*.18+
        Number(ab.topspin||10)*.11+Number(ab.slice||10)*.08+Number(ab.patience||10)*.09;
      const extPhysicalA=Number(aa.strength||10)*.12+Number(aa.acceleration||10)*.17+
        Number(aa.agility||10)*.17+Number(aa.balance||10)*.11+Number(aa.flexibility||10)*.08+
        Number(aa.work_rate||10)*.11+Number(aa.defensive_skill||10)*.12+Number(aa.court_positioning||10)*.12;
      const extPhysicalB=Number(ab.strength||10)*.12+Number(ab.acceleration||10)*.17+
        Number(ab.agility||10)*.17+Number(ab.balance||10)*.11+Number(ab.flexibility||10)*.08+
        Number(ab.work_rate||10)*.11+Number(ab.defensive_skill||10)*.12+Number(ab.court_positioning||10)*.12;
      const extMentalA=Number(aa.fighting_spirit||10)*.27+Number(aa.killer_instinct||10)*.22+
        Number(aa.determination||10)*.23+Number(aa.patience||10)*.10+Number(aa.leadership||10)*.07+Number(aa.work_rate||10)*.11;
      const extMentalB=Number(ab.fighting_spirit||10)*.27+Number(ab.killer_instinct||10)*.22+
        Number(ab.determination||10)*.23+Number(ab.patience||10)*.10+Number(ab.leadership||10)*.07+Number(ab.work_rate||10)*.11;
      const extNetA=Number(aa.half_volley||10)*.19+Number(aa.smash||10)*.18+Number(aa.lob||10)*.12+
        Number(aa.slice||10)*.12+Number(aa.transition_game||10)*.22+Number(aa.court_positioning||10)*.17;
      const extNetB=Number(ab.half_volley||10)*.19+Number(ab.smash||10)*.18+Number(ab.lob||10)*.12+
        Number(ab.slice||10)*.12+Number(ab.transition_game||10)*.22+Number(ab.court_positioning||10)*.17;
      let extComboA=0,extComboB=0;
      if(courtSpeed>=1.08){
        extComboA=extServeA*.27+extGroundA*.20+extPhysicalA*.19+extMentalA*.17+extNetA*.17;
        extComboB=extServeB*.27+extGroundB*.20+extPhysicalB*.19+extMentalB*.17+extNetB*.17;
      }else if(courtSpeed<=.82){
        extComboA=extServeA*.12+extGroundA*.31+extPhysicalA*.24+extMentalA*.18+extNetA*.15;
        extComboB=extServeB*.12+extGroundB*.31+extPhysicalB*.24+extMentalB*.18+extNetB*.15;
      }else{
        extComboA=extServeA*.20+extGroundA*.26+extPhysicalA*.22+extMentalA*.17+extNetA*.15;
        extComboB=extServeB*.20+extGroundB*.26+extPhysicalB*.22+extMentalB*.17+extNetB*.15;
      }
      const extendedAttributeFit=Math.max(-.14,Math.min(.14,(extComboA-extComboB)/65));

      let h2h=0,h2hSummary:any=null;
      if(hrow){
        const aIsCanonical=aid===Number(hrow.player_a_id);
        const aw=aIsCanonical?Number(hrow.a_wins||0):Number(hrow.b_wins||0);
        const bw=aIsCanonical?Number(hrow.b_wins||0):Number(hrow.a_wins||0);
        const total=aw+bw;
        let saw=0,sbw=0;
        if(isClay){saw=aIsCanonical?Number(hrow.clay_a_wins||0):Number(hrow.clay_b_wins||0);sbw=aIsCanonical?Number(hrow.clay_b_wins||0):Number(hrow.clay_a_wins||0)}
        else if(isGrass){saw=aIsCanonical?Number(hrow.grass_a_wins||0):Number(hrow.grass_b_wins||0);sbw=aIsCanonical?Number(hrow.grass_b_wins||0):Number(hrow.grass_a_wins||0)}
        else if(indoor){saw=aIsCanonical?Number(hrow.indoor_a_wins||0):Number(hrow.indoor_b_wins||0);sbw=aIsCanonical?Number(hrow.indoor_b_wins||0):Number(hrow.indoor_a_wins||0)}
        else{saw=aIsCanonical?Number(hrow.hard_a_wins||0):Number(hrow.hard_b_wins||0);sbw=aIsCanonical?Number(hrow.hard_b_wins||0):Number(hrow.hard_a_wins||0)}
        const sn=saw+sbw;
        const recentA=aIsCanonical?Number(hrow.recent_a_wins||0):Number(hrow.recent_b_wins||0);
        const recentB=aIsCanonical?Number(hrow.recent_b_wins||0):Number(hrow.recent_a_wins||0);
        const rn=recentA+recentB;
        h2h=(total?((aw-bw)/total)*Math.min(.055,total*.007):0)
          +(sn?((saw-sbw)/sn)*Math.min(.045,sn*.009):0)
          +(rn?((recentA-recentB)/rn)*Math.min(.025,rn*.006):0);
        h2hSummary={a_wins:aw,b_wins:bw,matches:total,surface_a_wins:saw,surface_b_wins:sbw,surface_matches:sn,last_match_date:hrow.last_match_date};
      }

      let userTactics=0;
      if(a.isUser||b.isUser){
        const sign=a.isUser?1:-1;
        const balance=100-Math.abs(tacticAgg-62)*.22-Math.abs(tacticRisk-54)*.18;
        const netFit=isGrass?tacticNet*.035:indoor?tacticNet*.028:!isClay?tacticNet*.018:tacticNet*.006;
        const ret=returnPos==="Avancée"?1.4:returnPos==="Reculée"?.8:1.1;
        let bonus=balance*.025+netFit+ret+staffMatchBonus;
        if(Number(c.fatigue||18)>45&&tacticAgg>75)bonus-=2.8;
        if(tacticRisk>80)bonus-=1.8;
        userTactics=sign*bonus/24;
      }

      const formDelta=(Number(a.form||70)-Number(b.form||70))*.0052;
      const baseLogit=Math.log(Math.max(.01,Math.min(.99,eloProb))/Math.max(.01,1-Math.min(.99,eloProb)));
      let logit=baseLogit+serviceReturn*.54+mental*.20+physical*.16+surfaceFit*.20+
        styleMatch*.38+tacticalFit*.42+contextFit*.18+bigMatchFit*.16+bo5Fit*.22+
        confidenceFit+paceFit+h2h+formDelta+userTactics+extendedAttributeFit;
      if(bestOf>=5)logit*=1.10;
      let probA=1/(1+Math.exp(-logit));
      probA=Math.max(.035,Math.min(.965,probA));
      return {probA,components:{
        elo_probability:eloProb,surface_elo_a:aElo,surface_elo_b:bElo,
        service_return:serviceReturn,mental,physical,surface_fit:surfaceFit,pace_fit:paceFit,
        style_matchup:styleMatch,tactical_matchup:tacticalFit,context_skill:contextFit,
        big_match:bigMatchFit,best_of_five:bo5Fit,confidence:confidenceFit,
        h2h,form_delta:formDelta,user_tactics:userTactics,h2h_summary:h2hSummary,
        extended_attribute_adjustment:extendedAttributeFit,
        extended_attributes:{
          serve_a:extServeA,serve_b:extServeB,ground_a:extGroundA,ground_b:extGroundB,
          physical_a:extPhysicalA,physical_b:extPhysicalB,mental_a:extMentalA,mental_b:extMentalB,
          net_a:extNetA,net_b:extNetB,combined_a:extComboA,combined_b:extComboB
        }
      }};
    };

    const generateScore=(probA:number,aWon:boolean,bo=bestOf)=>{
      const target=bo>=5?3:2;
      const closeness=1-Math.min(1,Math.abs(probA-.5)*2);
      const loseSetChance=Math.max(.04,Math.min(.54,.10+closeness*.34+(bo>=5?.06:0)));
      let loserSets=0;
      for(let i=0;i<target-1;i++)if(Math.random()<loseSetChance)loserSets++;
      if(bo>=5&&loserSets<2&&Math.random()<loseSetChance*.55)loserSets++;
      loserSets=Math.min(target-1,loserSets);
      const sequence:Array<"W"|"L">=[];
      for(let i=0;i<target-1;i++)sequence.push("W");
      for(let i=0;i<loserSets;i++)sequence.push("L");
      for(let i=sequence.length-1;i>0;i--){const j=Math.floor(Math.random()*(i+1));[sequence[i],sequence[j]]=[sequence[j],sequence[i]]}
      sequence.push("W");
      const tbChance=Math.max(.08,Math.min(.52,.13+closeness*.25+Math.max(0,courtSpeed-1)*.45));
      return sequence.map(result=>{
        const matchWinnerTakesSet=result==="W";
        const setWinnerIsA=matchWinnerTakesSet?aWon:!aWon;
        const tight=Math.random()<(.30+closeness*.42);
        let w=6,l=2+Math.floor(Math.random()*3);
        if(tight&&Math.random()<tbChance){w=7;l=6}
        else if(tight){w=7;l=5}
        const aScore=setWinnerIsA?w:l,bScore=setWinnerIsA?l:w;
        return aWon?(aScore+"-"+bScore):(bScore+"-"+aScore);
      }).join(" ");
    };

    const play=(a:any,b:any)=>{
      const model=matchupModel(a,b);
      const aWon=Math.random()<model.probA;
      const winner=aWon?a:b,loser=aWon?b:a;
      return {winner,loser,score:generateScore(model.probA,aWon,bestOf),model};
    };
    const matchRows:any[]=[];
    let performanceBye=false,performanceByeInfo:any=null,performanceByePlayers:any[]=[];
    let userAlive=true,userRound=frozenEntryMode==="lucky_loser"?"Lucky Loser":specialExempt?"Special Exempt":wildcardGranted?"Wild Card":alternateEntered?"Alternate entré":"Non joué",qualifier=false,luckyLoser=frozenEntryMode==="lucky_loser";
    let userQualifyingLossRound:string|null=luckyLoser?String(frozenEntryStatus?.loss_round_code||"")||null:null;
    let userHadBye=false,userMainWins=0;
    let juniorGroupPosition:number|null=null,juniorGroupWins=0;
    let champion:any=null;

    if(isJuniorSingles&&String(t.junior_draw_format||"")==="round_robin_to_elimination"&&drawSize===32&&!isJuniorFinals){
      const seeded=[user,...pool.slice(0,31)]
        .sort((a:any,b:any)=>Number(a.ranking||999999)-Number(b.ranking||999999)||strength(b)-strength(a));
      if(seeded.length<32)return h({error:"Tableau Junior RR incomplet : 32 joueurs requis.",qualified:seeded.length},409);

      const groups:any[][]=Array.from({length:8},()=>[]);
      for(let g=0;g<8;g++)groups[g].push(seeded[g]);
      for(let wave=0;wave<3;wave++){
        const chunk=seeded.slice(8+wave*8,16+wave*8);
        chunk.forEach((p:any,idx:number)=>{
          const groupIndex=wave%2===0?idx:7-idx;
          groups[groupIndex].push(p);
        });
      }

      const table=new Map<number,{player:any,wins:number,losses:number,group:number}>();
      for(let gi=0;gi<groups.length;gi++){
        for(const p of groups[gi])table.set(Number(p.id),{player:p,wins:0,losses:0,group:gi});
      }

      let rrNo=1;
      for(let gi=0;gi<groups.length;gi++){
        const g=groups[gi];
        for(let i=0;i<g.length;i++)for(let j=i+1;j<g.length;j++){
          const a=g[i],b=g[j],res=play(a,b);
          const w=table.get(Number(res.winner.id)),l=table.get(Number(res.loser.id));
          if(w)w.wins++;
          if(l)l.losses++;
          matchRows.push({
            round_no:rrNo++,round_name:"Groupe "+String.fromCharCode(65+gi),
            player_a_id:a.id,player_b_id:b.id,player_a_name:a.name,player_b_name:b.name,
            winner_id:res.winner.id,winner_name:res.winner.name,score:res.score
          });
        }
      }

      const rankedGroups=groups.map((g:any[])=>g.slice().sort((a:any,b:any)=>{
        const ta=table.get(Number(a.id)),tb=table.get(Number(b.id));
        return Number(tb?.wins||0)-Number(ta?.wins||0)
          ||strength(b)-strength(a)
          ||Number(a.ranking||999999)-Number(b.ranking||999999);
      }));

      for(const rg of rankedGroups){
        const idx=rg.findIndex((p:any)=>p.isUser);
        if(idx>=0){
          juniorGroupPosition=idx+1;
          juniorGroupWins=Number(table.get(Number(user.id))?.wins||0);
        }
      }

      const qfPlayers=[
        rankedGroups[0][0],rankedGroups[4][0],
        rankedGroups[2][0],rankedGroups[6][0],
        rankedGroups[1][0],rankedGroups[5][0],
        rankedGroups[3][0],rankedGroups[7][0]
      ];

      if(!qfPlayers.some((p:any)=>p.isUser)){
        userAlive=false;
        userRound="Phase de groupes";
      }

      const qfWinners:any[]=[];
      for(let qfi=0;qfi<4;qfi++){
        const a=qfPlayers[qfi*2],b=qfPlayers[qfi*2+1],res=play(a,b);
        matchRows.push({
          round_no:100+qfi,round_name:"QF",
          player_a_id:a.id,player_b_id:b.id,player_a_name:a.name,player_b_name:b.name,
          winner_id:res.winner.id,winner_name:res.winner.name,score:res.score
        });
        if((a.isUser||b.isUser)&&!res.winner.isUser){userAlive=false;userRound="QF";}
        if(res.winner.isUser)userRound="QF";
        qfWinners.push(res.winner);
      }

      const sfWinners:any[]=[];
      for(let sfi=0;sfi<2;sfi++){
        const a=qfWinners[sfi*2],b=qfWinners[sfi*2+1],res=play(a,b);
        matchRows.push({
          round_no:200+sfi,round_name:"SF",
          player_a_id:a.id,player_b_id:b.id,player_a_name:a.name,player_b_name:b.name,
          winner_id:res.winner.id,winner_name:res.winner.name,score:res.score
        });
        if((a.isUser||b.isUser)&&!res.winner.isUser){userAlive=false;userRound="SF";}
        if(res.winner.isUser)userRound="SF";
        sfWinners.push(res.winner);
      }

      const finalRes=play(sfWinners[0],sfWinners[1]);
      matchRows.push({
        round_no:300,round_name:"F",
        player_a_id:sfWinners[0].id,player_b_id:sfWinners[1].id,
        player_a_name:sfWinners[0].name,player_b_name:sfWinners[1].name,
        winner_id:finalRes.winner.id,winner_name:finalRes.winner.name,score:finalRes.score
      });
      if((sfWinners[0].isUser||sfWinners[1].isUser)&&!finalRes.winner.isUser){userAlive=false;userRound="F";}
      if(finalRes.winner.isUser)userRound="Champion";
      champion=finalRes.winner;
    }else if(isJuniorFinals){
      const ordered=[user,...pool].slice(0,8).sort((a:any,b:any)=>Number(a.ranking||999)-Number(b.ranking||999));
      if(ordered.length<8)return h({error:"Junior Finals : 8 qualifiés requis dans la Race.",qualified:ordered.length},409);
      const groups:any[][]=[
        [ordered[0],ordered[3],ordered[4],ordered[7]],
        [ordered[1],ordered[2],ordered[5],ordered[6]]
      ];
      const table=new Map<number,{player:any,wins:number,losses:number}>();
      ordered.forEach((p:any)=>table.set(Number(p.id),{player:p,wins:0,losses:0}));
      let rrNo=1;
      for(let gi=0;gi<groups.length;gi++){
        const g=groups[gi];
        for(let i=0;i<g.length;i++)for(let j=i+1;j<g.length;j++){
          const a=g[i],b=g[j],res=play(a,b);
          const wa=table.get(Number(res.winner.id)),lo=table.get(Number(res.loser.id));
          if(wa)wa.wins++;if(lo)lo.losses++;
          matchRows.push({
            round_no:rrNo++,round_name:"Groupe "+(gi===0?"A":"B"),
            player_a_id:a.id,player_b_id:b.id,player_a_name:a.name,player_b_name:b.name,
            winner_id:res.winner.id,winner_name:res.winner.name,score:res.score
          });
        }
      }
      const rankGroup=(g:any[])=>g.slice().sort((a:any,b:any)=>{
        const ta=table.get(Number(a.id)),tb=table.get(Number(b.id));
        return Number(tb?.wins||0)-Number(ta?.wins||0)||strength(b)-strength(a)||Number(a.ranking||999)-Number(b.ranking||999);
      });
      const ga=rankGroup(groups[0]),gb=rankGroup(groups[1]);
      const semifinalists=[ga[0],gb[1],gb[0],ga[1]];
      if(!semifinalists.some((p:any)=>p.isUser)){userAlive=false;userRound="Phase de groupes";}
      const sfWinners:any[]=[];
      for(let sfi=0;sfi<2;sfi++){
        const a=semifinalists[sfi*2],b=semifinalists[sfi*2+1],res=play(a,b);
        matchRows.push({
          round_no:100+sfi,round_name:"SF",
          player_a_id:a.id,player_b_id:b.id,player_a_name:a.name,player_b_name:b.name,
          winner_id:res.winner.id,winner_name:res.winner.name,score:res.score
        });
        if((a.isUser||b.isUser)&&!res.winner.isUser){userAlive=false;userRound="SF";}
        if(res.winner.isUser)userRound="SF";
        sfWinners.push(res.winner);
      }
      const finalRes=play(sfWinners[0],sfWinners[1]);
      matchRows.push({
        round_no:200,round_name:"F",
        player_a_id:sfWinners[0].id,player_b_id:sfWinners[1].id,
        player_a_name:sfWinners[0].name,player_b_name:sfWinners[1].name,
        winner_id:finalRes.winner.id,winner_name:finalRes.winner.name,score:finalRes.score
      });
      if((sfWinners[0].isUser||sfWinners[1].isUser)&&!finalRes.winner.isUser){userAlive=false;userRound="F";}
      if(finalRes.winner.isUser)userRound="Champion";
      champion=finalRes.winner;
    }else{
      qualifier=frozenEntryPhase==="qualifying"
        ||entryMode==="qualifying"
        ||entryMode==="protected_qualifying"
        ||entryMode.endsWith("_qualifying");
      const qDraw=Math.max(0,Number(t.qualifying_draw_size??formatRule?.qualifying_draw_size??0));
      const qSlots=Math.max(0,Number(formatRule?.qualifier_count||0));
      const qPlan=qualifyingSectionPlan(qDraw,qSlots);
      const qualifierWinners:any[]=[];
      const qualifyingFinalLosers:any[]=[];
      if(qPlan.sectionCount>0&&qualifyingCandidateIdsForRun.size){
        const qIds=new Set(qualifyingCandidateIdsForRun);
        const targetOpponents=Math.max(0,qPlan.drawSize-(qualifier?1:0));
        const qField:any[]=pool
          .filter((p:any)=>qIds.has(Number(p.id)))
          .slice(0,targetOpponents)
          .map((p:any)=>({...p,isUser:false,entry_method:"qualifying"}));
        const qUsed=new Set(qField.map((p:any)=>Number(p.id)));
        if(qualifier){
          qField.push({...user,entry_method:"qualifying"});
          qUsed.add(Number(user.id));
        }
        if(qField.length<qPlan.drawSize){
          for(const p of pool){
            const pid=Number(p.id);
            if(!pid||qUsed.has(pid)||Number(p.ranking||999999)<=Number(direct||0))continue;
            qField.push({...p,isUser:false,entry_method:"qualifying"});
            qUsed.add(pid);
            if(qField.length>=qPlan.drawSize)break;
          }
        }
        qField.sort((a:any,b:any)=>Number(a.ranking||999999)-Number(b.ranking||999999)||strength(b)-strength(a));

        const sections:any[][]=Array.from({length:qPlan.sectionCount},()=>Array(qPlan.sectionSize).fill(null));
        const primary=qField.slice(0,qPlan.sectionCount);
        const secondary=qField.slice(qPlan.sectionCount,qPlan.sectionCount*2).reverse();
        primary.forEach((p:any,i:number)=>{if(p)sections[i][0]=p});
        secondary.forEach((p:any,i:number)=>{if(p)sections[i][qPlan.sectionSize-1]=p});

        // Non-power-of-two qualifying sections (e.g. ITF 48Q / 8 qualifiers)
        // live inside the next power-of-two mini bracket. Put the byes beside
        // the two seeds first, then fill the interior draw positions.
        const rest=qField.slice(qPlan.sectionCount*2);
        let restIndex=0;
        for(let section=0;section<qPlan.sectionCount;section++){
          const sectionPlayers=Math.max(
            2,
            Math.min(
              qPlan.sectionSize,
              Number(qPlan.sectionPlayers||Math.ceil(qPlan.drawSize/qPlan.sectionCount))
            )
          );
          let byes=Math.max(0,qPlan.sectionSize-sectionPlayers);
          const reservedBye=new Set<number>();
          if(byes>0){reservedBye.add(1);byes--}
          if(byes>0){reservedBye.add(qPlan.sectionSize-2);byes--}
          for(let pos=2;byes>0&&pos<qPlan.sectionSize-2;pos++){
            if(!reservedBye.has(pos)){reservedBye.add(pos);byes--}
          }

          for(let pos=1;pos<qPlan.sectionSize-1;pos++){
            if(reservedBye.has(pos))continue;
            if(restIndex<rest.length)sections[section][pos]=rest[restIndex++];
          }
        }

        for(let section=0;section<sections.length;section++){
          let current:any[]=sections[section];
          let qr=1;
          while(current.length>1){
            const next:any[]=[];
            const rn="Q"+qr;
            for(let qi=0;qi<current.length;qi+=2){
              const a=current[qi],b=current[qi+1];
              if(!a&&!b){next.push(null);continue}
              if(!a||!b){next.push(a||b);continue}
              const res=play(a,b);
              matchRows.push({
                round_no:-Math.max(1,qPlan.rounds-qr+1),round_name:rn,
                player_a_id:a.id,player_b_id:b.id,player_a_name:a.name,player_b_name:b.name,
                winner_id:res.winner.id,winner_name:res.winner.name,score:res.score
              });
              if(qr===qPlan.rounds)qualifyingFinalLosers.push(res.loser);
              if((a.isUser||b.isUser)&&!res.winner.isUser){
                userAlive=false;userRound=rn;userQualifyingLossRound=rn;
              }
              if(res.winner.isUser){
                userAlive=true;userRound=rn;
              }
              next.push(res.winner);
            }
            current=next;
            qr++;
          }
          if(current[0])qualifierWinners.push({...current[0],entry_method:"qualifier"});
        }

        if(qualifier){
          const qualified=qualifierWinners.some((p:any)=>p.isUser);
          if(qualified){
            userAlive=true;userRound="Qualifié";
          }else{
            const lostFinal=userRound==="Q"+qPlan.rounds;
            const llSpots=Math.max(0,(forfeits.data??[]).length);
            if(lostFinal&&llSpots>0){
              const luckyOrder=qualifyingFinalLosers.slice().sort((a:any,b:any)=>Number(a.ranking||999999)-Number(b.ranking||999999));
              if(luckyOrder.slice(0,llSpots).some((p:any)=>p.isUser)){
                userAlive=true;luckyLoser=true;userRound="Lucky Loser";
              }
            }
          }
        }
      }

      const qualifierIds=new Set(qualifierWinners.map((p:any)=>Number(p.id)).filter(Boolean));
      let mainBase:any[];
      if(structuredJuniorEntry){
        const wcSlots=Math.max(0,Number(formatRule?.wildcard_count||0));
        const targetMainBase=Math.max(0,drawSize-qualifierWinners.length);
        const juniorDirectSlots=Math.max(0,drawSize-Math.max(0,Number(formatRule?.qualifier_count||0))-wcSlots);
        const directMain=pool
          .filter((p:any)=>Number(p.ranking||999999)<=Number(direct))
          .slice(0,juniorDirectSlots)
          .map((p:any)=>({...p,isUser:false,entry_method:"direct"}));
        const usedMainIds=new Set(directMain.map((p:any)=>Number(p.id)).filter(Boolean));
        const wildcardPool=pool
          .filter((p:any)=>!qualifyingCandidateIdsForRun.has(Number(p.id))&&!qualifierIds.has(Number(p.id))&&!usedMainIds.has(Number(p.id))&&Number(p.ranking||999999)>Number(qual))
          .sort((a:any,b:any)=>{
            const ah=String(a.country||"")===String(t.country||"")?0:1;
            const bh=String(b.country||"")===String(t.country||"")?0:1;
            return ah-bh||Number(a.ranking||999999)-Number(b.ranking||999999);
          })
          .slice(0,wcSlots)
          .map((p:any)=>({...p,isUser:false,entry_method:"wildcard"}));
        wildcardPool.forEach((p:any)=>usedMainIds.add(Number(p.id)));
        mainBase=[...directMain,...wildcardPool];
        if(mainBase.length<targetMainBase){
          const fillers=pool
            .filter((p:any)=>!qualifyingCandidateIdsForRun.has(Number(p.id))&&!qualifierIds.has(Number(p.id))&&!usedMainIds.has(Number(p.id)))
            .slice(0,targetMainBase-mainBase.length)
            .map((p:any)=>({...p,isUser:false,entry_method:"wildcard"}));
          mainBase.push(...fillers);
        }
      }else{
        mainBase=pool
          .filter((p:any)=>!qualifyingCandidateIdsForRun.has(Number(p.id))&&!qualifierIds.has(Number(p.id)))
          .map((p:any)=>({...p,isUser:false,entry_method:"direct"}));
      }
      let participants=[
        ...mainBase.slice(0,Math.max(0,drawSize-qualifierWinners.length)),
        ...qualifierWinners
      ];
      if(userAlive&&!participants.some((p:any)=>p?.isUser)){
        const taggedUser={...user,entry_method:luckyLoser?"lucky_loser":entryMode};
        let replaceIndex=participants.length-1;
        for(let pi=participants.length-1;pi>=0;pi--){
          if(String(participants[pi]?.entry_method||"")!=="qualifier"){replaceIndex=pi;break}
        }
        if(replaceIndex>=0)participants[replaceIndex]=taggedUser;
        else participants.push(taggedUser);
      }
      participants=participants.slice(0,drawSize);

      const pbSlots=Math.max(0,Number(t.performance_bye_slots||0));
      let pbCandidateSet=new Set<number>();
      if(pbSlots>0){
        const [pbCandidates,managedPb]=await Promise.all([
          db.rpc("tournament_performance_bye_candidate_ids",{p_target_tournament_id:tid}),
          db.rpc("player_performance_bye_status",{p_player_id:managedId,p_target_tournament_id:tid})
        ]);
        if(pbCandidates.error||managedPb.error)return h({error:(pbCandidates.error||managedPb.error)?.message},500);
        pbCandidateSet=new Set((pbCandidates.data??[]).map((x:any)=>Number(x.player_id)).filter(Boolean));
        performanceBye=Boolean(managedPb.data?.eligible);
        performanceByeInfo=managedPb.data||null;
        if(pbCandidateSet.has(managedId)&&!performanceBye)pbCandidateSet.delete(managedId);
      }

      const bracketSize=drawSize<=8?8:drawSize<=16?16:drawSize<=32?32:drawSize<=64?64:128;
      const seedSlot=(bracket:number,seed:number)=>{
        const slots=bracket>=128?[1,128,65,64,33,96,97,32,17,112,81,48,49,80,113,16,9,120,73,56,41,88,105,24,25,104,89,40,57,72,121,8]
          :bracket>=64?[1,64,33,32,17,48,49,16,9,56,41,24,25,40,57,8]
          :bracket>=32?[1,32,17,16,9,24,25,8]
          :bracket>=16?[1,16,9,8]:[1,8];
        return seed>=1&&seed<=slots.length?slots[seed-1]-1:null;
      };

      let rankedEntrants=[...participants].sort((a:any,b:any)=>Number(a.ranking||999999)-Number(b.ranking||999999)||Number(b.current_ability||0)-Number(a.current_ability||0));
      const seedEligibleEntrants=rankedEntrants.filter((p:any)=>!["qualifier","lucky_loser"].includes(String(p.entry_method||"")));
      const configuredSeedCount=Math.min(Number(formatRule?.seed_count||Math.min(32,Math.max(2,bracketSize/4))),seedEligibleEntrants.length);
      const seededIds=new Set(seedEligibleEntrants.slice(0,configuredSeedCount).map((p:any)=>Number(p.id)).filter(Boolean));
      let pbEntrants=rankedEntrants
        .filter((p:any)=>!seededIds.has(Number(p.id))&&pbCandidateSet.has(Number(p.id)))
        .slice(0,pbSlots);

      if(pbEntrants.length){
        const pbIds=new Set(pbEntrants.map((p:any)=>Number(p.id)));
        for(let k=0;k<pbEntrants.length;k++){
          let drop=-1;
          for(let j=rankedEntrants.length-1;j>=0;j--){
            const candidate=rankedEntrants[j];
            if(!pbIds.has(Number(candidate.id))&&!candidate.isUser){drop=j;break}
          }
          if(drop>=0)rankedEntrants.splice(drop,1);
        }
        pbEntrants=pbEntrants.filter((p:any)=>rankedEntrants.some((x:any)=>Number(x.id)===Number(p.id)));
        performanceByePlayers=pbEntrants.map((p:any)=>({id:Number(p.id),name:String(p.name||""),is_user:Boolean(p.isUser)}));
        performanceBye=performanceByePlayers.some((p:any)=>p.is_user);
      }

      const bracket:any[]=Array(bracketSize).fill(null);
      const placed=new Set<number>();
      const seedCount=Math.min(configuredSeedCount,rankedEntrants.length);
      for(let s=1;s<=seedCount;s++){
        const slot=seedSlot(bracketSize,s);
        if(slot==null)continue;
        bracket[slot]=seedEligibleEntrants[s-1];
        placed.add(Number(seedEligibleEntrants[s-1].id));
      }

      const regularByeCount=Math.max(0,bracketSize-drawSize);
      const byeSlots=new Set<number>();
      for(let s=1;s<=Math.min(regularByeCount,seedCount);s++){
        const slot=seedSlot(bracketSize,s);
        if(slot==null)continue;
        const bye=slot%2===0?slot+1:slot-1;
        byeSlots.add(bye);
      }

      for(const pb of pbEntrants){
        if(placed.has(Number(pb.id)))continue;
        let chosen=-1;
        for(let s=0;s<bracketSize;s+=2){
          if(bracket[s]==null&&bracket[s+1]==null&&!byeSlots.has(s)&&!byeSlots.has(s+1)){
            chosen=s;break;
          }
        }
        if(chosen>=0){
          bracket[chosen]=pb;
          placed.add(Number(pb.id));
          byeSlots.add(chosen+1);
        }
      }

      const remaining=rankedEntrants.filter((x:any)=>!placed.has(Number(x.id)));
      const available:number[]=[];
      for(let i=0;i<bracketSize;i++)if(bracket[i]==null&&!byeSlots.has(i))available.push(i);
      remaining.forEach((p:any,i:number)=>{if(i<available.length)bracket[available[i]]=p;});

      const roundName=(n:number,roundNo:number)=>{
        if(roundNo===1&&drawSize!==bracketSize)return "R"+drawSize;
        return n>=128?"R128":n>=64?"R64":n>=32?"R32":n>=16?"R16":n>=8?"QF":n>=4?"SF":"F";
      };
      let roundNo=1;
      userHadBye=false;userMainWins=0;
      let current:any[]=bracket;
      while(current.length>1){
        const rn=roundName(current.length,roundNo),next:any[]=[];
        for(let i=0;i<current.length;i+=2){
          const a=current[i],b=current[i+1];
          if(!a&&!b){next.push(null);continue}
          if(!a||!b){
            const adv=a||b;
            if(adv?.isUser&&roundNo===1)userHadBye=true;
            next.push(adv);
            continue;
          }
          const res=play(a,b);
          matchRows.push({round_no:roundNo,round_name:rn,player_a_id:a.id,player_b_id:b.id,player_a_name:a.name,player_b_name:b.name,winner_id:res.winner.id,winner_name:res.winner.name,score:res.score});
          if((a.isUser||b.isUser)&&!res.winner.isUser){userAlive=false;userRound=rn}
          if(res.winner.isUser){userMainWins++;userRound=rn==="F"?"Champion":rn}
          next.push(res.winner);
        }
        current=next;
        roundNo++;
      }
      champion=current[0];
    }

    let userPoints=0;
    if(isJuniorSingles){
      if(String(t.junior_draw_format||"")==="round_robin_to_elimination"&&userRound==="Phase de groupes"){
        const cat=String(t.category||t.level||"J30");
        if(juniorGroupPosition===2)userPoints=cat==="J60"?5:2;
        else if((juniorGroupPosition===3||juniorGroupPosition===4)&&juniorGroupWins>0)userPoints=cat==="J60"?2:1;
        else userPoints=0;
      }else{
        const roundCode=userRound==="Champion"?"W":userRound==="Phase de groupes"?"QF":userRound;
        const jp=await db.rpc("junior_points_for",{p_event_type:"singles",p_category:String(t.category||t.level||"J30"),p_round:roundCode});
        if(jp.error)return h({error:jp.error.message},500);
        userPoints=Number(jp.data||0);
      }
    }else if(isAtpSinglesFinals){
      const groupWins=matchRows.filter((m:any)=>String(m.round_name||"").startsWith("Groupe")&&m.winner_name===user.name).length;
      const sfWin=matchRows.some((m:any)=>m.round_name==="SF"&&m.winner_name===user.name)?1:0;
      const fWin=matchRows.some((m:any)=>m.round_name==="F"&&m.winner_name===user.name)?1:0;
      userPoints=groupWins*200+sfWin*400+fWin*500;
    }else{
      let pointsCode=userRound==="Champion"?"W":userRound;
      if(userHadBye&&userMainWins===0&&Array.isArray(formatRule?.rounds)&&formatRule.rounds.length)pointsCode=String(formatRule.rounds[0]);
      const pointsRes=await db.rpc("tournament_points_for_result",{p_tournament_id:tid,p_result_code:pointsCode,p_was_qualifier:qualifier&&!luckyLoser});
      if(pointsRes.error)return h({error:pointsRes.error.message},500);
      userPoints=Math.max(0,Number(pointsRes.data||0));
      if(luckyLoser&&userQualifyingLossRound){
        const llQualPoints=await db.rpc("tournament_points_for_result",{
          p_tournament_id:tid,p_result_code:userQualifyingLossRound,p_was_qualifier:false
        });
        if(llQualPoints.error)return h({error:llQualPoints.error.message},500);
        userPoints+=Math.max(0,Number(llQualPoints.data||0));
      }
      if(wildcardGranted&&userMainWins===0&&/Grand Chelem|Masters 1000/i.test(String(t.category||"")))userPoints=0;
    }

    let userPrize=0;
    if(isAtpSinglesFinals&&String(t.prize_format||"")==="round_robin_components"){
      const comp:any=t.special_prize_components?.singles||{};
      const groupWins=matchRows.filter((m:any)=>String(m.round_name||"").startsWith("Groupe")&&m.winner_name===user.name).length;
      const sfWin=matchRows.some((m:any)=>m.round_name==="SF"&&m.winner_name===user.name)?1:0;
      const fWin=matchRows.some((m:any)=>m.round_name==="F"&&m.winner_name===user.name)?1:0;
      userPrize=Math.max(0,Math.round(
        Number(comp.PARTICIPATION||0)
        +groupWins*Number(comp.RR_WIN||0)
        +sfWin*Number(comp.SF_WIN||0)
        +fWin*Number(comp.F_WIN||0)
      ));
    }else{
      const payout=tournamentRoundPrize(t,userRound,/^Q\d+$/.test(userRound)?"qualifying":"singles");
      userPrize=payout.amount;
    }
    const prizeFxRateToEur=prizeFxToEur(t.prize_currency||"USD");
    const userPrizeEur=prizeToBaseEur(userPrize,t.prize_currency||"USD");
    const runIns=await db.from("tournament_runs").insert({
      tournament_id:tid,managed_player_id:managedId,entry_method:entryMode,champion_player_id:champion?.id??null,user_round:userRound,user_points:userPoints,
      user_prize:userPrize,user_prize_eur:userPrizeEur,prize_fx_rate_to_eur:prizeFxRateToEur,status:"completed"
    }).select("id").single();
    if(runIns.error)return h({error:runIns.error.message},500);
    const runId=runIns.data.id;

    if(entryMode==="protected"||entryMode==="protected_qualifying"){
      const used=await db.rpc("consume_player_entry_protection",{
        p_player_id:managedId,p_event_type:"singles",p_tournament_id:tid
      });
      if(used.error||used.data?.ok===false){
        await db.from("tournament_runs").delete().eq("id",runId);
        return h({error:used.error?.message||"Impossible de consommer le classement protégé.",protected_ranking:used.data||null},500);
      }
      protectedRankingUse=used.data;
    }

    // Fictional Challenger/ITF series keep real career continuity:
    // once this edition has a champion, the next edition displays them as defending champion.
    if(t.is_verified===false&&["Challenger","ITF"].includes(String(t.circuit||""))&&champion?.id&&champion?.name){
      const season=Number(String(t.start_date||"").slice(0,4));
      if(Number.isFinite(season)&&season>0){
        const nextStart=`${season+1}-01-01`,nextEnd=`${season+2}-01-01`;
        await db.from("tournaments").update({
          defending_champion_player_id:Number(champion.id),
          defending_champion_name:String(champion.name),
          defending_champion_year:season,
          defending_champion_source:"Court Boss · saison simulée"
        })
        .eq("is_verified",false)
        .eq("name",String(t.name))
        .gte("start_date",nextStart)
        .lt("start_date",nextEnd);
      }
    }
    for(const m of matchRows){
      const pa=participantById.get(Number(m.player_a_id));
      const pb=participantById.get(Number(m.player_b_id));
      if(pa&&pb){
        const mm=matchupModel(pa,pb);
        m.player_a_win_probability=Number(mm.probA.toFixed(4));
        m.court_speed=Number(courtSpeed.toFixed(3));
        m.model_version="TA-H2H-v4-full-attrs";
        m.matchup_components=mm.components;
      }else{
        m.player_a_win_probability=null;
        m.court_speed=Number(courtSpeed.toFixed(3));
        m.model_version="TA-H2H-v4-full-attrs-fallback";
        m.matchup_components={};
      }
    }

    let matchLearning:any=null;
    let worldResultSync:any=null;
    if(matchRows.length){
      const rows=matchRows.map(x=>({...x,run_id:runId}));
      const ins=await db.from("tournament_draw_matches").insert(rows);
      if(ins.error)return h({error:ins.error.message},500);
      const learning=await db.rpc("apply_tournament_match_updates",{
        p_run_id:Number(runId),
        p_surface:surface,
        p_match_date:String(t.end_date||t.start_date||c.career_date||AGE_REFERENCE_DATE)
      });
      matchLearning=learning.error?{error:learning.error.message}:learning.data;

      if(!isJuniorSingles){
        const syncWorld=await db.rpc("populate_world_results_from_tournament_run",{
          p_run_id:Number(runId)
        });
        worldResultSync=syncWorld.error?{error:syncWorld.error.message}:syncWorld.data;
      }
    }

    const userAnalytics:any=advBy.get(Number(user.id))||{};
    const jitter=(span:number)=>(Math.random()-.5)*span;
    const userMatches=matchRows.filter(x=>x.player_a_name===user.name||x.player_b_name===user.name).map((m:any)=>{
      const won=m.winner_name===user.name;
      const userIsA=Number(m.player_a_id)===Number(user.id);
      const userProb=m.player_a_win_probability==null?null:(userIsA?Number(m.player_a_win_probability):1-Number(m.player_a_win_probability));
      const risk=Math.max(0,Math.min(100,tacticRisk));
      const aggression=Math.max(0,Math.min(100,tacticAgg));
      const net=Math.max(0,Math.min(100,tacticNet));
      const firstServe=Math.max(42,Math.min(82,Number(userAnalytics.first_serve_in_pct||62)-Math.max(0,risk-60)*.035+jitter(3)));
      const acePct=Math.max(.5,Math.min(25,Number(userAnalytics.ace_pct||6)+Math.max(0,courtSpeed-1)*7+jitter(1.4)));
      const dfPct=Math.max(.5,Math.min(12,Number(userAnalytics.double_fault_pct||4)+Math.max(0,risk-65)*.035+jitter(.8)));
      const winnerRate=Math.max(4,Math.min(35,Number(userAnalytics.winner_rate_pct||14)+(aggression-50)*.045+jitter(2)));
      const ueRate=Math.max(4,Math.min(32,Number(userAnalytics.unforced_error_pct||15)+(risk-50)*.055+jitter(2)));
      const rawComp=m.matchup_components||{};
      const scoreText=String(m.score||"");
      const setTokens=scoreText.match(/\d+\s*-\s*\d+/g)||[];
      const estimatedServicePoints=Math.max(28,Math.max(2,setTokens.length)*34+(/7\s*-\s*6|6\s*-\s*7/.test(scoreText)?10:0));
      const aceCount=Math.max(0,Math.round(estimatedServicePoints*acePct/100));
      const sign=userIsA?1:-1;
      const userComponents:any={
        elo_probability:userProb==null?null:Number(userProb.toFixed(4)),
        service_return:Number(rawComp.service_return||0)*sign,
        mental:Number(rawComp.mental||0)*sign,
        physical:Number(rawComp.physical||0)*sign,
        surface_fit:Number(rawComp.surface_fit||0)*sign,
        pace_fit:Number(rawComp.pace_fit||0)*sign,
        style_matchup:Number(rawComp.style_matchup||0)*sign,
        tactical_matchup:Number(rawComp.tactical_matchup||0)*sign,
        context_skill:Number(rawComp.context_skill||0)*sign,
        big_match:Number(rawComp.big_match||0)*sign,
        best_of_five:Number(rawComp.best_of_five||0)*sign,
        confidence:Number(rawComp.confidence||0)*sign,
        h2h:Number(rawComp.h2h||0)*sign,
        form_delta:Number(rawComp.form_delta||0)*sign,
        user_tactics:Number(rawComp.user_tactics||0)*sign
      };
      const stats={
        expected_win_probability:userProb==null?null:Number(userProb.toFixed(4)),
        model_version:"TA-H2H-v4-full-attrs",
        court_speed:m.court_speed,
        matchup_components:m.matchup_components||{},
        matchup_components_user:userComponents,
        first_serve_pct:Number(firstServe.toFixed(1)),
        ace_pct:Number(acePct.toFixed(1)),
        aces:aceCount,
        double_fault_pct:Number(dfPct.toFixed(1)),
        first_serve_points_won_pct:Number((Number(userAnalytics.first_serve_points_won_pct||68)+jitter(2.4)).toFixed(1)),
        second_serve_points_won_pct:Number((Number(userAnalytics.second_serve_points_won_pct||51)+jitter(2.2)).toFixed(1)),
        service_points_won_pct:Number((Number(userAnalytics.service_points_won_pct||61)+jitter(2)).toFixed(1)),
        return_points_won_pct:Number((Number(userAnalytics.return_points_won_pct||35)+jitter(2)).toFixed(1)),
        hold_pct:Number((Number(userAnalytics.hold_pct||78)+jitter(2.5)).toFixed(1)),
        break_pct:Number((Number(userAnalytics.break_pct||23)+jitter(2.5)).toFixed(1)),
        winners:Math.max(5,Math.round(winnerRate*1.25+Math.random()*4)),
        winner_rate_pct:Number(winnerRate.toFixed(1)),
        unforced_errors:Math.max(4,Math.round(ueRate*1.05+Math.random()*4)),
        unforced_error_pct:Number(ueRate.toFixed(1)),
        net_approach_pct:Number((Math.max(1,Number(userAnalytics.net_approach_pct||10)+(net-28)*.08+jitter(1.5))).toFixed(1)),
        net_points_won_pct:Number((Math.max(30,Math.min(90,Number(userAnalytics.net_points_won_pct||63)+jitter(3)))).toFixed(1)),
        avg_rally:Number((Math.max(2,Number(userAnalytics.avg_rally_shots||5)-(aggression-50)*.012+(isClay?.45:isGrass?-.35:0)+jitter(.5))).toFixed(1)),
        rally_1_3_win_pct:Number((Number(userAnalytics.rally_1_3_win_pct||50)+jitter(2)).toFixed(1)),
        rally_4_6_win_pct:Number((Number(userAnalytics.rally_4_6_win_pct||50)+jitter(2)).toFixed(1)),
        rally_7_9_win_pct:Number((Number(userAnalytics.rally_7_9_win_pct||50)+jitter(2)).toFixed(1)),
        rally_10plus_win_pct:Number((Number(userAnalytics.rally_10plus_win_pct||50)+jitter(2)).toFixed(1)),
        serve_impact:Number(userAnalytics.serve_impact||0),
        return_depth_score:Number(userAnalytics.return_depth_score||60),
        break_points_won:Math.max(0,Math.round((won?2.4:1.5)+Number(userAnalytics.break_points_converted_pct||40)/28+Math.random()*2)),
        tactical_plan:{aggression:tacticAgg,risk:tacticRisk,net:tacticNet,return_position:returnPos}
      };
      return {...m,stats};
    });
    for(const m of userMatches){
      await db.from("match_history").insert({
        managed_player_id:managedId,tournament_name:t.name,match_date:t.start_date,surface:t.surface,round:m.round_name,
        player_a:m.player_a_name,player_b:m.player_b_name,winner:m.winner_name,score:m.score,
        user_involved:true,match_data:{category:t.category,circuit:t.circuit,...m.stats}
      });
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
    const agentRep=await db.from("player_agency_representation").select("commission_pct").eq("player_id",managedId).eq("active",true).maybeSingle();
    const agentCommission=Math.max(0,Math.round(userPrizeEur*Math.min(20,Number(agentRep.data?.commission_pct||0))/100));
    let staffPerformanceBonus=0;
    if(userRound==="Champion"){
      const staffContracts=await db.from("contracts").select("weekly_salary,bonuses").eq("subject_type","staff").eq("status","active");
      const titleBonusMult=/Grand Chelem|Grand Slam/i.test(String(t.category||t.level||""))?4:/Masters 1000/i.test(String(t.category||t.level||""))?3:2;
      if(!staffContracts.error){
        staffPerformanceBonus=(staffContracts.data??[]).reduce((sum:number,x:any)=>{
          const demands=x.bonuses?.demands||{};
          return sum+(demands.performance_bonus?Math.round(Number(x.weekly_salary||0)*titleBonusMult):0);
        },0);
      }
    }
    let newPoints=Number(c.points||0),newRank=Number(c.singles_rank||2001);
    if(isJuniorSingles){
      if(userPoints>0){
        const current=await db.from("players").select("junior_game_points,junior_points").eq("id",managedId).maybeSingle();
        if(current.error)return h({error:current.error.message},500);
        await db.from("players").update({junior_game_points:Number(current.data?.junior_game_points||0)+userPoints}).eq("id",managedId);
      }
      const pr=await db.rpc("refresh_junior_display_pool_v3",{p_target:2000});
      if(pr.error)return h({error:pr.error.message},500);
      const jr=await db.from("junior_display_pool").select("display_rank").eq("player_id",managedId).maybeSingle();
      if(jr.error)return h({error:jr.error.message},500);
      newRank=Number(jr.data?.display_rank||newRank);
      const jp=await db.from("players").select("junior_points,junior_game_points").eq("id",managedId).maybeSingle();
      newPoints=Number(jp.data?.junior_points||0)+Number(jp.data?.junior_game_points||0);
    }else{
      if(userPoints>0){
        const earnedDate=String(t.end_date||t.start_date||new Date().toISOString().slice(0,10));
        const exp=new Date(earnedDate+"T12:00:00Z");exp.setUTCDate(exp.getUTCDate()+364);
        await db.from("user_ranking_points").insert({
          owner_id:"demo",player_id:managedId,tournament_id:tid,label:t.name,
          earned_date:earnedDate,expiry_date:exp.toISOString().slice(0,10),points:userPoints,active:true
        });
      }
      const rankingDate=String(t.end_date||t.start_date||new Date().toISOString().slice(0,10));
      const rankCalc=isPrimaryManaged
        ?await db.rpc("recalculate_user_ranking",{p_date:rankingDate})
        :await db.rpc("recalculate_managed_player_ranking",{
            p_player_id:managedId,p_date:rankingDate,p_sync_career:false
          });
      if(rankCalc.error)return h({error:rankCalc.error.message},500);
      newPoints=Number(rankCalc.data?.points??c.points??0);newRank=Number(rankCalc.data?.rank??c.singles_rank??2001);
    }
    const newBudget=Number(c.budget||0)+userPrizeEur-travelCost-agentCommission-staffPerformanceBonus;
    let staffAchievementCredit:any=null;
    if(userRound==="Champion"){
      const titleIns=await db.from("player_titles").insert({
        player_id:managedId,tournament_name:t.name,title_date:String(t.end_date||t.start_date),
        level:String(t.category||t.level||t.circuit||"ATP"),surface:String(t.surface||""),
        event_type:isJuniorSingles?"junior_singles":"singles",verified:false,source_label:isJuniorSingles?"Court Boss · titre junior simulé":"Court Boss · carrière simulée",origin:"game"
      }).select("id").single();
      if(titleIns.error)return h({error:titleIns.error.message},500);
      const credit=await db.rpc("credit_staff_title",{p_player_title_id:Number(titleIns.data.id)});
      staffAchievementCredit=credit.error?{error:credit.error.message}:credit.data;
    }
    let hiddenTraitEvolution:any=null;
    if(userRound==="Champion"||userRound==="F"){
      const earnedDate=String(t.end_date||t.start_date||c.career_date||AGE_REFERENCE_DATE);
      const finalMatch=matchRows.find((m:any)=>m.round_name==="F"&&(Number(m.player_a_id)===managedId||Number(m.player_b_id)===managedId));
      const opponentName=finalMatch
        ?(Number(finalMatch.player_a_id)===managedId?finalMatch.player_b_name:finalMatch.player_a_name)
        :null;
      const finalInsert=await db.from("player_final_results").insert({
        player_id:managedId,
        tournament_name:t.name,
        final_date:earnedDate,
        level:String(t.category||t.level||t.circuit||"ATP"),
        surface:String(t.surface||""),
        result:userRound==="Champion"?"Champion":"Finaliste",
        opponent_name:opponentName,
        source:"Court Boss simulation",
        event_type:isJuniorSingles?"junior_singles":"singles"
      }).select("id").single();
      if(finalInsert.error)return h({error:finalInsert.error.message},500);
      const hidden=await db.rpc("evolve_player_hidden_traits_from_results",{p_from_date:earnedDate,p_to_date:earnedDate});
      hiddenTraitEvolution=hidden.error?{error:hidden.error.message}:hidden.data;
    }
    const finState=await db.from("finances").select("prize_money,travel_cost,agent_commission,staff_bonus").eq("id","demo").maybeSingle();
    const careerRunUpdate=isPrimaryManaged
      ?(isJuniorSingles
        ?{budget:newBudget,fatigue:newFatigue,fitness:newFitness,form:newForm,updated_at:new Date().toISOString()}
        :{budget:newBudget,points:newPoints,singles_rank:newRank,fatigue:newFatigue,fitness:newFitness,form:newForm,updated_at:new Date().toISOString()})
      :{budget:newBudget,updated_at:new Date().toISOString()};
    await Promise.all([
      db.from("career_state").update(careerRunUpdate).eq("id","demo"),
      db.from("players").update({fatigue:newFatigue,fitness:newFitness,form:newForm}).eq("id",managedId),
      db.from("finances").update({
        prize_money:Number(finState.data?.prize_money||0)+userPrizeEur,
        travel_cost:Number(finState.data?.travel_cost||0)+travelCost,
        agent_commission:Number(finState.data?.agent_commission||0)+agentCommission,
        staff_bonus:Number(finState.data?.staff_bonus||0)+staffPerformanceBonus
      }).eq("id","demo"),
      db.from("news_items").insert({body:userRound==="Champion"?String(c.player_name||"Le joueur")+" remporte "+t.name+" !":String(c.player_name||"Le joueur")+" termine "+userRound+" à "+t.name+"."})
    ]);
    const earnedFinanceDate=String(t.end_date||t.start_date||c.career_date||AGE_REFERENCE_DATE);
    await recordFinanceTransactions([
      {transaction_key:"singles-run:"+runId+":prize",game_date:earnedFinanceDate,week:Number(c.week||0)||null,category:"prize_money",amount:userPrizeEur,source_type:"tournament_run",source_id:Number(runId),description:"Prize money · "+String(t.name),metadata:{result:userRound}},
      {transaction_key:"singles-run:"+runId+":travel",game_date:earnedFinanceDate,week:Number(c.week||0)||null,category:"travel",amount:-travelCost,source_type:"tournament_run",source_id:Number(runId),description:"Voyage · "+String(t.name)},
      {transaction_key:"singles-run:"+runId+":agent",game_date:earnedFinanceDate,week:Number(c.week||0)||null,category:"agent_commission",amount:-agentCommission,source_type:"tournament_run",source_id:Number(runId),description:"Commission agent · "+String(t.name)},
      {transaction_key:"singles-run:"+runId+":staff-bonus",game_date:earnedFinanceDate,week:Number(c.week||0)||null,category:"staff_bonus",amount:-staffPerformanceBonus,source_type:"tournament_run",source_id:Number(runId),description:"Prime performance staff · "+String(t.name),balance_after:newBudget}
    ]);
    const playedSinglesEntry=await db.from("entries")
      .select("id,metadata")
      .eq("tournament_id",tid)
      .eq("player_id",managedId)
      .eq("status","entered")
      .maybeSingle();
    if(playedSinglesEntry.error)return h({error:playedSinglesEntry.error.message},500);
    if(playedSinglesEntry.data?.id){
      const playedOn=String(t.end_date||t.start_date||c.career_date||AGE_REFERENCE_DATE);
      const entryDone=await db.from("entries").update({
        status:"played",
        withdrawn_on:null,
        metadata:{
          ...(playedSinglesEntry.data.metadata||{}),
          played_run_id:Number(runId),
          played_on:playedOn,
          result:userRound,
          entry_method:entryMode
        },
        updated_at:new Date().toISOString()
      }).eq("id",Number(playedSinglesEntry.data.id));
      if(entryDone.error)return h({error:entryDone.error.message},500);
    }

    const board=await db.rpc("update_board_state");
    return h({ok:true,run_id:runId,managed_player_id:managedId,managed_player_name:String(managedPlayer.data.name||c.player_name||"Joueur"),is_primary_managed:isPrimaryManaged,tournament:t,champion:{id:champion?.id??null,name:champion?.name||user.name},user_round:userRound,user_points:userPoints,user_prize:userPrize,user_prize_eur:userPrizeEur,prize_fx_rate_to_eur:prizeFxRateToEur,base_currency:BASE_CURRENCY,matches:userMatches,draw_matches:matchRows.length,match_model:"TA-H2H-v2",court_speed:courtSpeed,best_of:bestOf,match_learning:matchLearning,world_result_sync:worldResultSync,travel_cost:travelCost,agent_commission:agentCommission,staff_performance_bonus:staffPerformanceBonus,staff_achievement_credit:staffAchievementCredit,hidden_trait_evolution:hiddenTraitEvolution,fatigue_added:totalFatigue,fitness:newFitness,wildcard:wildcardGranted,lucky_loser:luckyLoser,lucky_loser_qualifying_loss_round:userQualifyingLossRound,alternate:alternateEntered,special_exempt:specialExempt,special_exempt_info:specialExemptInfo,entry_mode:entryMode,entry_ranking:entryRank,entry_ranking_date:entryRankingDate,entry_direct_cut:direct,entry_qual_cut:qual,entry_projection_model:entryProjectionModel,protected_ranking:protectedRankingInfo,protected_ranking_use:protectedRankingUse,performance_bye:performanceBye,performance_bye_info:performanceByeInfo,performance_bye_players:performanceByePlayers,new_rank:newRank,total_points:newPoints,board:board.data});
  }


  if(path.endsWith("/api/play-doubles")&&req.method==="POST"){
    let body:any;try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const tid=n(body?.tournament_id,0,1,99999999);
    const career=await db.from("career_state").select("*").eq("id","demo").maybeSingle();
    if(career.error||!career.data)return h({error:career.error?.message||"Carrière introuvable"},500);
    const primaryManagedId=Number(career.data.managed_player_id||0);
    const requestedManagedId=n(body?.player_id,primaryManagedId,1,99999999);
    if(!requestedManagedId)return h({error:"Joueur géré introuvable"},404);
    if(requestedManagedId!==primaryManagedId){
      const roster=await db.from("academy_roster").select("id").eq("player_id",requestedManagedId).eq("status","active").maybeSingle();
      if(roster.error)return h({error:roster.error.message},500);
      if(!roster.data)return h({error:"Ce joueur ne fait pas partie du groupe géré."},403);
    }
    const [tour,anth,oldRun,partnership]=await Promise.all([
      db.from("tournaments").select("*").eq("id",tid).maybeSingle(),
      db.from("players").select("id,name,country,doubles_ranking,doubles_points,junior_doubles_ranking,junior_doubles_game_points,current_ability,form,fitness,fatigue,career_focus,player_attributes(doubles,clay_affinity,hard_affinity,grass_affinity)").eq("id",requestedManagedId).maybeSingle(),
      db.from("doubles_runs").select("id").eq("tournament_id",tid).eq("managed_player_id",requestedManagedId).maybeSingle(),
      db.from("doubles_partnerships")
        .select("*,player_a:players!doubles_partnerships_player_a_id_fkey(id,name,country,doubles_ranking,junior_doubles_ranking,junior_doubles_game_points,current_ability,form,fitness,fatigue,player_attributes(doubles,clay_affinity,hard_affinity,grass_affinity)),player_b:players!doubles_partnerships_player_b_id_fkey(id,name,country,doubles_ranking,junior_doubles_ranking,junior_doubles_game_points,current_ability,form,fitness,fatigue,player_attributes(doubles,clay_affinity,hard_affinity,grass_affinity))")
        .or("player_a_id.eq."+requestedManagedId+",player_b_id.eq."+requestedManagedId)
        .order("id",{ascending:false}).limit(1).maybeSingle()
    ]);
    const err=tour.error||anth.error||oldRun.error||partnership.error;
    if(err)return h({error:err.message},500);
    if(!tour.data||!anth.data)return h({error:"Données carrière incomplètes"},404);
    if(oldRun.data)return h({error:"Ce joueur a déjà joué le double de ce tournoi.",run_id:oldRun.data.id,player_id:requestedManagedId},409);
    const pair:any=partnership.data||null;
    const partnerRaw:any=pair
      ?(Number(pair.player_a_id)===requestedManagedId
        ?(Array.isArray(pair.player_b)?pair.player_b[0]:pair.player_b)
        :(Array.isArray(pair.player_a)?pair.player_a[0]:pair.player_a))
      :null;
    const specialTeamEvent=specialTeamEventMeta(tour.data);
    if(specialTeamEvent)return h({
      error:"Cette compétition se joue par équipes et par sélection. Le tableau de double standard est désactivé.",
      team_event:specialTeamEvent,registration_mode:tour.data.registration_mode||null
    },409);
    const managedDoubleFocus=String(anth.data.career_focus||career.data.career_focus||"mixed");
    if(managedDoubleFocus==="singles_only"){
      return h({error:"Orientation Simple exclusivement : ce joueur ne participe pas aux tableaux de double.",career_focus:"singles_only",singles_only:true},409);
    }
    if(!tour.data.doubles)return h({error:"Ce tournoi ne propose pas le double."},409);
    if(!partnerRaw)return h({error:"Choisis d’abord un partenaire de double."},409);
    if(String(tour.data.circuit)==="Junior"&&!partnerRaw.junior_doubles_ranking){
      return h({error:"Choisis un partenaire du circuit Junior Double pour ce tournoi."},409);
    }

    const t:any=tour.data,c:any={
      ...career.data,
      player_name:String(anth.data.name||career.data.player_name||"Joueur"),
      country:String(anth.data.country||career.data.country||"FRA"),
      doubles_rank:Number(anth.data.doubles_ranking??career.data.doubles_rank??3000),
      doubles_points:Number(anth.data.doubles_points??career.data.doubles_points??0),
      current_ability:Number(anth.data.current_ability??career.data.current_ability??55),
      form:Number(anth.data.form??career.data.form??70),
      fitness:Number(anth.data.fitness??career.data.fitness??90),
      fatigue:Number(anth.data.fatigue??career.data.fatigue??15),
      career_focus:managedDoubleFocus
    };
    const autoQualifiedDoublesFinals=(
      (String(t.circuit)==="ATP"&&/ATP Finals/i.test(String(t.category||"")))
      ||(String(t.circuit)==="Junior"&&/Junior Double Finals/i.test(String(t.category||"")))
    );
    let persistedDoubleEntry:any=null;
    if(!autoQualifiedDoublesFinals){
      const persisted=await db.from("managed_doubles_entries")
        .select("*")
        .eq("owner_id","demo")
        .eq("tournament_id",tid)
        .eq("player_id",Number(anth.data.id))
        .eq("partner_id",Number(partnerRaw.id))
        .eq("status","entered")
        .maybeSingle();
      if(persisted.error)return h({error:persisted.error.message},500);
      if(!persisted.data){
        return h({
          error:"Inscris d’abord cette paire au tournoi avant de jouer le double.",
          requires_persisted_entry:true,
          tournament_id:tid,
          partner_id:Number(partnerRaw.id)
        },409);
      }
      persistedDoubleEntry=persisted.data;
    }

    let doublesEntryStatus:any=null;
    let protectedDoubleUse:any=null;
    if(["ATP","Challenger","ITF"].includes(String(t.circuit))||/Grand Chelem/i.test(String(t.category||""))){
      doublesEntryStatus=await managedDoublesEntryStatus(t,Number(anth.data.id));
      const entryStatus=doublesEntryStatus;
      if(entryStatus.can_schedule===false){
        return h({error:entryStatus.label||"Inscription double impossible.",doubles_entry_status:entryStatus},409);
      }
      if(entryStatus.projected_acceptance===false){
        return h({
          error:"Paire hors de la ligne d’acceptation projetée pour ce tableau. Reste sur la liste d’alternates ou vise un tournoi adapté.",
          doubles_entry_status:entryStatus
        },409);
      }
    }
    const doublesCalendarMode=doublesEntryStatus?.requires_qualifying?"qualifying":"direct";
    if(Number(anth.data.id)===primaryManagedId){
      const doubleSchedule=await db.rpc("managed_tournament_schedule_status",{
        p_target_tournament_id:tid,p_entry_mode:doublesCalendarMode
      });
      if(doubleSchedule.error)return h({error:doubleSchedule.error.message},500);
      if(doubleSchedule.data?.available===false){
        return h({
          error:"Conflit de calendrier : ce double chevauche un autre engagement de la sauvegarde.",
          schedule_conflict:doubleSchedule.data
        },409);
      }
    }
    const partner:any={...partnerRaw,player_attributes:Array.isArray(partnerRaw.player_attributes)?partnerRaw.player_attributes[0]:partnerRaw.player_attributes};
    const anthony:any={...anth.data,player_attributes:Array.isArray(anth.data.player_attributes)?anth.data.player_attributes[0]:anth.data.player_attributes,isUser:true};

    const [managedDoubleSchedule,partnerDoubleSchedule]=await Promise.all([
      db.rpc("player_tournament_calendar_conflict",{p_player_id:Number(anthony.id),p_tournament_id:tid,p_entry_method:doublesCalendarMode}),
      db.rpc("player_tournament_calendar_conflict",{p_player_id:Number(partner.id),p_tournament_id:tid,p_entry_method:doublesCalendarMode})
    ]);
    if(managedDoubleSchedule.error||partnerDoubleSchedule.error){
      return h({error:(managedDoubleSchedule.error||partnerDoubleSchedule.error)?.message},500);
    }
    if(managedDoubleSchedule.data?.conflict===true){
      return h({error:"Conflit de calendrier : tu es déjà engagé dans un autre tournoi cette semaine.",schedule_conflict:managedDoubleSchedule.data},409);
    }
    if(partnerDoubleSchedule.data?.conflict===true){
      return h({error:"Ton partenaire est déjà engagé dans un autre tournoi incompatible avec ce double.",partner_schedule_conflict:partnerDoubleSchedule.data,partner:{id:partner.id,name:partner.name}},409);
    }

    const isJuniorDouble=String(t.circuit)==="Junior";
    const isJuniorDoubleFinals=/Junior Double Finals/i.test(String(t.category||""));
    const isAtpDoubleFinals=String(t.circuit)==="ATP"&&/ATP Finals/i.test(String(t.category||""));
    let finalsPairRows:any[]=[];
    if(isJuniorDoubleFinals){
      const race=await db.rpc("junior_doubles_race_for_date",{p_date:String(c.career_date||AGE_REFERENCE_DATE)});
      if(race.error)return h({error:race.error.message},500);
      const usedFinals=new Set<number>();
      finalsPairRows=[];
      for(const x of race.data??[]){
        const aid=Number((x as any).player_one_id||0),bid=Number((x as any).player_two_id||0);
        if(!aid||!bid||aid===bid||usedFinals.has(aid)||usedFinals.has(bid))continue;
        finalsPairRows.push(x);usedFinals.add(aid);usedFinals.add(bid);
        if(finalsPairRows.length>=8)break;
      }
      const own=finalsPairRows.find((x:any)=>
        (Number(x.player_one_id)===Number(anthony.id)&&Number(x.player_two_id)===Number(partner.id))
        ||(Number(x.player_one_id)===Number(partner.id)&&Number(x.player_two_id)===Number(anthony.id))
      );
      if(!own)return h({error:"Paire non qualifiée pour les Junior Doubles Finals : Top 8 de la Race requis.",race_required:8},409);
    }else if(isAtpDoubleFinals){
      const race=await db.rpc("doubles_race_for_date",{p_date:String(c.career_date||AGE_REFERENCE_DATE)});
      if(race.error)return h({error:race.error.message},500);
      finalsPairRows=(race.data??[]).slice(0,8);
      const own=finalsPairRows.find((x:any)=>
        (Number(x.player_one_id)===Number(anthony.id)&&Number(x.player_two_id)===Number(partner.id))
        ||(Number(x.player_one_id)===Number(partner.id)&&Number(x.player_two_id)===Number(anthony.id))
      );
      if(!own)return h({error:"Paire non qualifiée pour les ATP Finals : Top 8 de la Race Double requis.",race_required:8},409);
    }

    const configuredDoubleDraw=tournamentDoublesDrawConfig(t).drawSize;
    const drawSize=finalsPairRows.length?8:configuredDoubleDraw;
    const managedDoubleQualifying=!finalsPairRows.length
      &&Boolean(doublesEntryStatus?.requires_qualifying)
      &&String(t.circuit)==="ATP"
      &&/ATP 500/i.test(String(t.category||""));
    const pairPoolTarget=Math.max(0,drawSize-1+(managedDoubleQualifying?3:0));
    let poolRes:any;
    let worldPairRows:any[]=[];
    let projectedRacePairRows:any[]=[];
    if(finalsPairRows.length){
      const ids=[...new Set(finalsPairRows.flatMap((x:any)=>[Number(x.player_one_id),Number(x.player_two_id)]).filter(Boolean))];
      poolRes=await db.from("players")
        .select("id,name,country,doubles_ranking,junior_doubles_ranking,junior_doubles_game_points,current_ability,form,fitness,fatigue,player_attributes(doubles,clay_affinity,hard_affinity,grass_affinity)")
        .in("id",ids);
    }else if(isJuniorDouble){
      poolRes=await db.from("players")
        .select("id,name,country,junior_doubles_ranking,current_ability,form,fitness,fatigue,player_attributes(doubles,clay_affinity,hard_affinity,grass_affinity)")
        .not("junior_doubles_ranking","is",null)
        .or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*")
        .order("junior_doubles_ranking",{ascending:true}).limit(160);
    }else{
      const refYear=Number(String(c.career_date||AGE_REFERENCE_DATE).slice(0,4));
      if(refYear>2025){
        const wp=await db.from("world_doubles_partnerships")
          .select("id,race_rank,race_points,chemistry,compatibility,pair_strength,affinity_score,player_a:players!world_doubles_partnerships_player_a_id_fkey(id,name,country,doubles_ranking,current_ability,form,fitness,fatigue,player_attributes(doubles,clay_affinity,hard_affinity,grass_affinity)),player_b:players!world_doubles_partnerships_player_b_id_fkey(id,name,country,doubles_ranking,current_ability,form,fitness,fatigue,player_attributes(doubles,clay_affinity,hard_affinity,grass_affinity))")
          .eq("season",refYear).eq("active",true)
          .order("race_rank",{ascending:true})
          .limit(256);
        if(!wp.error)worldPairRows=wp.data??[];
      }

      const projected=await projectedDoublesTournamentRows(
        t,
        refDate,
        Math.max(96,drawSize*2),
        [Number(anthony.id),Number(partner.id)]
      );
      if(!projected.error)projectedRacePairRows=projected.rows;

      if(worldPairRows.length||projectedRacePairRows.length){
        const byId=new Map<number,any>();
        for(const x of worldPairRows){
          const a:any=(x as any).player_a,b:any=(x as any).player_b;
          if(a?.id)byId.set(Number(a.id),a);
          if(b?.id)byId.set(Number(b.id),b);
        }
        const projectedIds=[...new Set(projectedRacePairRows.flatMap((x:any)=>[
          Number(x.player_one_id||0),Number(x.player_two_id||0)
        ]).filter(Boolean))].filter((id:number)=>!byId.has(id));
        if(projectedIds.length){
          const projectedPool=await db.from("players")
            .select("id,name,country,doubles_ranking,junior_doubles_ranking,junior_doubles_game_points,current_ability,form,fitness,fatigue,player_attributes(doubles,clay_affinity,hard_affinity,grass_affinity,net_positioning,volley,doubles_communication,poaching,return_consistency,return_game,first_serve_quality,serve_precision,big_points,composure)")
            .in("id",projectedIds);
          if(projectedPool.error)return h({error:projectedPool.error.message},500);
          for(const p of projectedPool.data??[])if((p as any)?.id)byId.set(Number((p as any).id),p);
        }
        const rankedPool=await db.from("players")
          .select("id,name,country,doubles_ranking,junior_doubles_ranking,junior_doubles_game_points,current_ability,form,fitness,fatigue,player_attributes(doubles,clay_affinity,hard_affinity,grass_affinity)")
          .eq("is_real",true).not("doubles_ranking","is",null)
          .or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*")
          .order("doubles_ranking",{ascending:true}).limit(Math.min(256,Math.max(160,drawSize*3)));
        if(rankedPool.error)return h({error:rankedPool.error.message},500);
        for(const p of rankedPool.data??[])if((p as any)?.id&&!byId.has(Number((p as any).id)))byId.set(Number((p as any).id),p);
        poolRes={data:[...byId.values()],error:null};
      }else{
        poolRes=await db.from("players")
          .select("id,name,country,doubles_ranking,junior_doubles_ranking,junior_doubles_game_points,current_ability,form,fitness,fatigue,player_attributes(doubles,clay_affinity,hard_affinity,grass_affinity)")
          .eq("is_real",true).not("doubles_ranking","is",null)
          .or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*")
          .order("doubles_ranking",{ascending:true}).limit(160);
      }
    }
    if(poolRes.error)return h({error:poolRes.error.message},500);
    const pool=(poolRes.data??[])
      .filter((p:any)=>p.id!==partner.id&&p.id!==anthony.id)
      .map((p:any)=>({...p,player_attributes:Array.isArray(p.player_attributes)?p.player_attributes[0]:p.player_attributes}));

    const doublesStaffIds=[...new Set([
      Number(anthony.id),Number(partner.id),
      ...pool.map((p:any)=>Number(p.id)).filter(Boolean)
    ])];
    const doublesStaffRows=doublesStaffIds.length
      ?await db.from("player_staff_assignments")
        .select("player_id,staff:staff_profiles(doubles_coaching_rating,serve_coaching_rating,return_coaching_rating,communication_rating,professionalism,workload,burnout,travel_fatigue)")
        .in("player_id",doublesStaffIds).eq("active",true).eq("role","Coach double")
      :{data:[],error:null};
    if(doublesStaffRows.error)return h({error:doublesStaffRows.error.message},500);
    const doublesCoachByPlayer=new Map<number,number>();
    for(const row of doublesStaffRows.data??[]){
      const sp:any=Array.isArray((row as any).staff)?(row as any).staff[0]:(row as any).staff||{};
      const eff=Math.max(.68,Math.min(1.06,
        1-Number(sp.burnout||0)*.0032-Number(sp.travel_fatigue||0)*.0018
        -Math.max(0,Number(sp.workload||20)-75)*.0015
        +Math.max(0,Number(sp.professionalism||10)-14)*.006
      ));
      const quality=(
        Number(sp.doubles_coaching_rating||10)*.50+
        Number(sp.serve_coaching_rating||10)*.18+
        Number(sp.return_coaching_rating||10)*.18+
        Number(sp.communication_rating||10)*.14
      )*eff;
      doublesCoachByPlayer.set(Number((row as any).player_id),Math.max(doublesCoachByPlayer.get(Number((row as any).player_id))||0,quality));
    }

    const surface=String(t.surface||"Dur");
    const key=surface==="Terre"?"clay_affinity":surface==="Gazon"?"grass_affinity":"hard_affinity";
    const playerStrength=(p:any)=>{
      const aa=p.player_attributes||{};
      return Number(p.current_ability||50)*.50+Number(p.form||70)*.10+Number(p.fitness||85)*.06-Number(p.fatigue||20)*.08
        +Number(aa.doubles||10)*.70+Number(aa[key]||10)*.42
        +Number(aa.net_positioning||aa.volley||10)*.28
        +Number(aa.doubles_communication||aa.doubles||10)*.22
        +Number(aa.poaching||aa.volley||10)*.20
        +Number(aa.return_consistency||aa.return_game||10)*.17
        +Number(aa.first_serve_quality||aa.serve_precision||10)*.15
        +Number(aa.big_points||aa.composure||10)*.12;
    };
    const pairCoachBonus=(a:any,b:any)=>{
      const qa=Number(doublesCoachByPlayer.get(Number(a?.id))||10);
      const qb=Number(doublesCoachByPlayer.get(Number(b?.id))||10);
      return Math.max(0,Math.min(2.2,((qa+qb)/2-10)*.16));
    };
    const pairStrength=(a:any,b:any,chem=70)=>playerStrength(a)+playerStrength(b)+chem*.18+pairCoachBonus(a,b);

    const ownRaceRow=finalsPairRows.find((x:any)=>
      (Number(x.player_one_id)===Number(anthony.id)&&Number(x.player_two_id)===Number(partner.id))
      ||(Number(x.player_one_id)===Number(partner.id)&&Number(x.player_two_id)===Number(anthony.id))
    );
    const userPair={
      a:anthony,b:partner,name:anthony.name+" / "+partner.name,isUser:true,
      strength:pairStrength(anthony,partner,Number(partnership.data.chemistry||70)),
      race_rank:Number(ownRaceRow?.doubles_race_ranking??ownRaceRow?.junior_doubles_race_ranking??999),
      race_points:Number(ownRaceRow?.doubles_race_points??ownRaceRow?.junior_doubles_race_points??0),
      entry_rank:Number(ownRaceRow?.doubles_race_ranking??ownRaceRow?.junior_doubles_race_ranking)
        ||(Number(anthony.doubles_ranking||9999)+Number(partner.doubles_ranking||9999))
    };
    const pairs:any[]=[];
    if(finalsPairRows.length){
      const byId=new Map<number,any>([
        ...pool.map((p:any)=>[Number(p.id),p] as [number,any]),
        [Number(anthony.id),anthony],
        [Number(partner.id),partner]
      ]);
      for(const row of finalsPairRows){
        const a:any=byId.get(Number(row.player_one_id));
        const b:any=byId.get(Number(row.player_two_id));
        if(!a||!b)continue;
        const isUserPair=(Number(a.id)===Number(anthony.id)&&Number(b.id)===Number(partner.id))
          ||(Number(a.id)===Number(partner.id)&&Number(b.id)===Number(anthony.id));
        if(isUserPair)continue;
        pairs.push({
          a,b,name:String(row.name||a.name+" / "+b.name),isUser:false,
          strength:pairStrength(a,b,70),
          race_rank:Number(row.doubles_race_ranking??row.junior_doubles_race_ranking??999),
          race_points:Number(row.doubles_race_points??row.junior_doubles_race_points??0)
        });
      }
    }else{
      const used=new Set<number>([Number(anthony.id),Number(partner.id)]);
      const addPair=(a:any,c:any,meta:any={})=>{
        const aid=Number(a?.id||0),bid=Number(c?.id||0);
        if(!aid||!bid||aid===bid||used.has(aid)||used.has(bid)||pairs.length>=pairPoolTarget)return false;
        const raceRank=Number(meta.race_rank||9999);
        pairs.push({
          a,b:c,name:String(meta.name||a.name+" / "+c.name),isUser:false,
          strength:pairStrength(a,c,Number(meta.chemistry||70)),
          race_rank:raceRank,
          race_points:Number(meta.race_points||0),
          chemistry:Number(meta.chemistry||70),
          compatibility:Number(meta.compatibility||70),
          world_pair_id:Number(meta.world_pair_id||0),
          entry_rank:raceRank<9999?raceRank:Number(a.doubles_ranking||9999)+Number(c.doubles_ranking||9999),
          projected:Boolean(meta.projected),
          source:String(meta.source||"")
        });
        used.add(aid);used.add(bid);
        return true;
      };

      for(const row of worldPairRows){
        const a0:any=(row as any).player_a,c0:any=(row as any).player_b;
        if(!a0?.id||!c0?.id)continue;
        const a:any={...a0,player_attributes:Array.isArray(a0.player_attributes)?a0.player_attributes[0]:a0.player_attributes};
        const c:any={...c0,player_attributes:Array.isArray(c0.player_attributes)?c0.player_attributes[0]:c0.player_attributes};
        addPair(a,c,{
          name:a.name+" / "+c.name,
          race_rank:Number((row as any).race_rank||9999),
          race_points:Number((row as any).race_points||0),
          chemistry:Number((row as any).chemistry||70),
          compatibility:Number((row as any).compatibility||70),
          world_pair_id:Number((row as any).id||0),
          source:"active-world-pair"
        });
        if(pairs.length>=pairPoolTarget)break;
      }

      if(pairs.length<pairPoolTarget&&projectedRacePairRows.length){
        const byId=new Map<number,any>(pool.map((p:any)=>[Number(p.id),p]));
        for(const row of projectedRacePairRows){
          const a:any=byId.get(Number(row.player_one_id));
          const c:any=byId.get(Number(row.player_two_id));
          if(!a||!c)continue;
          addPair(a,c,{
            name:String(row.name||a.name+" / "+c.name),
            race_rank:Number(row.doubles_race_ranking||9999),
            race_points:Number(row.doubles_race_points||0),
            chemistry:72,
            projected:true,
            source:"doubles-race-projection"
          });
          if(pairs.length>=pairPoolTarget)break;
        }
      }

      if(pairs.length<pairPoolTarget){
        let pending:any=null;
        for(const candidate of pool){
          const cid=Number(candidate?.id||0);
          if(!cid||used.has(cid))continue;
          if(!pending){pending=candidate;continue}
          const a:any=pending,c:any=candidate;pending=null;
          addPair(a,c,{
            name:a.name+" / "+c.name,
            race_rank:9999,
            chemistry:66,
            projected:true,
            source:"ranking-projection"
          });
          if(pairs.length>=pairPoolTarget)break;
        }
      }
    }
    if(!finalsPairRows.length&&pairs.length<pairPoolTarget){
      return h({error:"Tableau double incomplet : pas assez de paires éligibles.",required:pairPoolTarget+1,available:pairs.length+1,qualifying:managedDoubleQualifying},409);
    }
    const matches:any[]=[];
    let userRound=finalsPairRows.length?"Phase de groupes":"R16";
    const playPair=(A:any,B:any)=>{
      const prob=1/(1+Math.exp(-(A.strength-B.strength)/8));
      const Aw=Math.random()<prob,w=Aw?A:B,l=Aw?B:A;
      const close=Math.abs(A.strength-B.strength)<8;
      const score=close?(Math.random()<.5?"7-6 4-6 10-8":"6-4 3-6 10-7"):(Aw?"6-3 6-4":"4-6 3-6");
      return {winner:w,loser:l,score};
    };
    const pushPairMatch=(round:string,A:any,B:any,res:any)=>{
      const involvesUser=!!A.isUser||!!B.isUser;
      matches.push({
        round_name:round,
        user_pair:involvesUser?userPair.name:null,
        opponent_pair:A.isUser?B.name:B.isUser?A.name:A.name+" vs "+B.name,
        winner_pair:res.winner.name,score:res.score
      });
    };

    if(finalsPairRows.length){
      const ordered=[userPair,...pairs].slice(0,8).sort((a:any,b:any)=>Number(a.race_rank||999)-Number(b.race_rank||999));
      if(ordered.length<8)return h({error:"Finals double : 8 paires qualifiées requises.",qualified:ordered.length},409);
      const groups:any[][]=[
        [ordered[0],ordered[3],ordered[4],ordered[7]],
        [ordered[1],ordered[2],ordered[5],ordered[6]]
      ];
      const table=new Map<string,{team:any,wins:number,losses:number}>();
      ordered.forEach((p:any)=>table.set(String(p.name),{team:p,wins:0,losses:0}));
      for(let gi=0;gi<groups.length;gi++){
        const g=groups[gi];
        for(let i=0;i<g.length;i++)for(let j=i+1;j<g.length;j++){
          const A=g[i],B=g[j],res=playPair(A,B);
          const w=table.get(String(res.winner.name)),l=table.get(String(res.loser.name));
          if(w)w.wins++;if(l)l.losses++;
          pushPairMatch("Groupe "+(gi===0?"A":"B"),A,B,res);
        }
      }
      const rankGroup=(g:any[])=>g.slice().sort((a:any,b:any)=>{
        const ta=table.get(String(a.name)),tb=table.get(String(b.name));
        return Number(tb?.wins||0)-Number(ta?.wins||0)
          ||Number(b.strength||0)-Number(a.strength||0)
          ||Number(a.race_rank||999)-Number(b.race_rank||999);
      });
      const ga=rankGroup(groups[0]),gb=rankGroup(groups[1]);
      const semifinalists=[ga[0],gb[1],gb[0],ga[1]];
      if(!semifinalists.some((p:any)=>p.isUser))userRound="Phase de groupes";
      const sfWinners:any[]=[];
      for(let sfi=0;sfi<2;sfi++){
        const A=semifinalists[sfi*2],B=semifinalists[sfi*2+1],res=playPair(A,B);
        pushPairMatch("SF",A,B,res);
        if((A.isUser||B.isUser)&&!res.winner.isUser)userRound="SF";
        if(res.winner.isUser)userRound="SF";
        sfWinners.push(res.winner);
      }
      const finalRes=playPair(sfWinners[0],sfWinners[1]);
      pushPairMatch("F",sfWinners[0],sfWinners[1],finalRes);
      if((sfWinners[0].isUser||sfWinners[1].isUser)&&!finalRes.winner.isUser)userRound="F";
      if(finalRes.winner.isUser)userRound="Champion";
    }else{
      let qualifyingBonusPoints=0;
      let qualifyingExit=false;
      let mainPairs=pairs.slice();

      if(managedDoubleQualifying){
        const orderedForEntry=pairs.slice().sort((a:any,b:any)=>
          Number(a.entry_rank||999999)-Number(b.entry_rank||999999)
          ||Number(b.strength||0)-Number(a.strength||0)
        );
        const qRivals=orderedForEntry.slice(-3);
        if(qRivals.length<3){
          return h({error:"Qualifications double ATP 500 incomplètes : 4 équipes requises.",required:4,available:qRivals.length+1},409);
        }
        const qNames=new Set(qRivals.map((p:any)=>String(p.name)));
        mainPairs=pairs.filter((p:any)=>!qNames.has(String(p.name)));

        const qTeams=[userPair,...qRivals].sort((a:any,b:any)=>
          Number(a.entry_rank||999999)-Number(b.entry_rank||999999)
          ||Number(b.strength||0)-Number(a.strength||0)
        );
        const qSemiA=playPair(qTeams[0],qTeams[3]);
        const qSemiB=playPair(qTeams[1],qTeams[2]);
        pushPairMatch("DQ1",qTeams[0],qTeams[3],qSemiA);
        pushPairMatch("DQ1",qTeams[1],qTeams[2],qSemiB);

        const userSemi=[qSemiA,qSemiB].find((x:any)=>x.winner.isUser||x.loser.isUser);
        if(userSemi&&!userSemi.winner.isUser){
          userRound="DQ1";
          qualifyingExit=true;
        }

        const qFinal=playPair(qSemiA.winner,qSemiB.winner);
        pushPairMatch("DQF",qSemiA.winner,qSemiB.winner,qFinal);
        if(!qualifyingExit&&(qSemiA.winner.isUser||qSemiB.winner.isUser)){
          if(qFinal.winner.isUser){
            qualifyingBonusPoints=45;
            userRound="R16";
          }else{
            userRound="DQF";
            qualifyingBonusPoints=25;
            qualifyingExit=true;
          }
        }
      }

      if(!qualifyingExit){
      const entrants=[userPair,...mainPairs].slice(0,drawSize);
      const bracketSize=drawSize<=8?8:drawSize<=16?16:drawSize<=32?32:64;
      const slots:any[]=Array(bracketSize).fill(null);
      const byeCount=Math.max(0,bracketSize-drawSize);
      const seedSlot=(bracket:number,seed:number)=>{
        const ss=bracket>=64?[1,64,33,32,17,48,49,16,9,56,41,24,25,40,57,8]
          :bracket>=32?[1,32,17,16,9,24,25,8]
          :bracket>=16?[1,16,9,8]:[1,8];
        return seed>=1&&seed<=ss.length?ss[seed-1]-1:null;
      };
      const seedCount=Math.min(bracketSize>=64?16:bracketSize>=32?8:bracketSize>=16?4:2,entrants.length);
      const seedOrder=entrants.slice().sort((a:any,c:any)=>
        Number(a.entry_rank||999999)-Number(c.entry_rank||999999)
        ||Number(c.strength||0)-Number(a.strength||0)
      );
      const placed=new Set<string>();
      for(let s=1;s<=seedCount;s++){
        const slot=seedSlot(bracketSize,s);
        if(slot==null)continue;
        const seeded=seedOrder[s-1];
        slots[slot]=seeded;
        placed.add(String(seeded.name));
      }
      const byeSlots=new Set<number>();
      for(let s=1;s<=Math.min(byeCount,seedCount);s++){
        const slot=seedSlot(bracketSize,s);
        if(slot==null)continue;
        byeSlots.add(slot%2===0?slot+1:slot-1);
      }
      const drawKey=(p:any)=>{
        const aId=Number(p?.a?.id||0),bId=Number(p?.b?.id||0);
        return Math.abs(((aId*73856093)^(bId*19349663)^(tid*83492791))>>>0);
      };
      const rest=entrants.filter((x:any)=>!placed.has(String(x.name))).sort((a:any,c:any)=>drawKey(a)-drawKey(c));
      const avail:number[]=[];
      for(let i=0;i<bracketSize;i++)if(slots[i]==null&&!byeSlots.has(i))avail.push(i);
      rest.forEach((p:any,i:number)=>{if(i<avail.length)slots[avail[i]]=p;});

      let current:any[]=slots;
      let roundNo=1;
      while(current.length>1){
        const rn=roundNo===1&&drawSize!==bracketSize?"R"+drawSize:(current.length>=64?"R64":current.length>=32?"R32":current.length>=16?"R16":current.length>=8?"QF":current.length>=4?"SF":"F");
        const next:any[]=[];
        for(let i=0;i<current.length;i+=2){
          const A=current[i],B=current[i+1];
          if(!A&&!B){next.push(null);continue}
          if(!A||!B){next.push(A||B);continue}
          const res=playPair(A,B);
          pushPairMatch(rn,A,B,res);
          if((A.isUser||B.isUser)&&!res.winner.isUser)userRound=rn;
          if(res.winner.isUser)userRound=rn==="F"?"Champion":rn;
          next.push(res.winner);
        }
        current=next;
        roundNo++;
      }
      }
    }

    const cat=String(t.category||t.level||"");
    let pts=0;
    if(isJuniorDouble){
      const roundCode=userRound==="Champion"?"W":userRound==="Phase de groupes"?"QF":userRound;
      const jp=await db.rpc("junior_points_for",{p_event_type:"doubles",p_category:String(t.category||t.level||"J30"),p_round:roundCode});
      if(jp.error)return h({error:jp.error.message},500);
      pts=Number(jp.data||0);
    }else if(isAtpDoubleFinals){
      const groupWins=matches.filter((m:any)=>String(m.round_name||"").startsWith("Groupe")&&m.winner_pair===userPair.name).length;
      const sfWin=matches.some((m:any)=>m.round_name==="SF"&&m.winner_pair===userPair.name)?1:0;
      const fWin=matches.some((m:any)=>m.round_name==="F"&&m.winner_pair===userPair.name)?1:0;
      pts=groupWins*200+sfWin*400+fWin*500;
    }else{
      if(userRound==="DQ1"){
        pts=0;
      }else if(userRound==="DQF"){
        pts=25;
      }else{
        const roundCode=userRound==="Champion"?"W":userRound;
        const rankingCode=/^R(?:24|28)$/.test(roundCode)?"R32":roundCode;
        const dp=await db.rpc("doubles_points_for_result",{p_category:cat,p_draw_size:drawSize,p_result:rankingCode});
        if(dp.error)return h({error:dp.error.message},500);
        const qBonus=managedDoubleQualifying?45:0;
        pts=Math.max(0,Number(dp.data||0)+qBonus);
      }
    }

    const qualifyingPointsEarned=managedDoubleQualifying
      ?(userRound==="DQF"?25:userRound==="DQ1"?0:45)
      :0;

    let teamPrize=0;
    if(isAtpDoubleFinals&&String(t.prize_format||"")==="round_robin_components"){
      const comp:any=t.special_prize_components?.doubles_team||{};
      const groupWins=matches.filter((m:any)=>String(m.round_name||"").startsWith("Groupe")&&m.winner_pair===userPair.name).length;
      const sfWin=matches.some((m:any)=>m.round_name==="SF"&&m.winner_pair===userPair.name)?1:0;
      const fWin=matches.some((m:any)=>m.round_name==="F"&&m.winner_pair===userPair.name)?1:0;
      teamPrize=Math.max(0,Math.round(
        Number(comp.PARTICIPATION||0)
        +groupWins*Number(comp.RR_WIN||0)
        +sfWin*Number(comp.SF_WIN||0)
        +fWin*Number(comp.F_WIN||0)
      ));
    }else{
      teamPrize=/^DQ(?:1|F)$/.test(userRound)
        ?0
        :tournamentRoundPrize(t,userRound,"doubles").amount;
    }
    const prize=Math.round(teamPrize/2*100)/100;
    const prizeFxRateToEur=prizeFxToEur(t.prize_currency||"USD");
    const prizeEur=prizeToBaseEur(prize,t.prize_currency||"USD");

    const doublesRunEntryMethod=managedDoubleQualifying
      ?(userRound==="DQ1"||userRound==="DQF"
        ?(doublesEntryStatus?.use_protected_ranking?"protected_qualifying":"qualifying")
        :(doublesEntryStatus?.use_protected_ranking?"protected_qualifier":"qualifier"))
      :(doublesEntryStatus?.use_protected_ranking?"protected":"direct");
    const run=await db.from("doubles_runs").insert({
      tournament_id:tid,managed_player_id:Number(anthony.id),partnership_id:partnership.data.id,partner_id:partner.id,
      entry_method:doublesRunEntryMethod,qualifying_points:qualifyingPointsEarned,
      user_round:userRound,user_points:pts,
      user_prize:prize,user_prize_eur:prizeEur,prize_fx_rate_to_eur:prizeFxRateToEur,status:"completed"
    }).select("id").single();
    if(run.error)return h({error:run.error.message},500);

    if(doublesEntryStatus?.use_protected_ranking===true){
      const used=await db.rpc("consume_player_entry_protection",{
        p_player_id:Number(anthony.id),p_event_type:"doubles",p_tournament_id:tid
      });
      if(used.error||used.data?.ok===false){
        await db.from("doubles_runs").delete().eq("id",run.data.id);
        return h({error:used.error?.message||"Impossible de consommer le classement protégé double.",protected_ranking:used.data||null},500);
      }
      protectedDoubleUse=used.data;
    }

    if(matches.length){
      const rows=matches.filter((m:any)=>m.user_pair===userPair.name).map((m:any)=>({...m,run_id:run.data.id}));
      if(rows.length){
        const ins=await db.from("doubles_match_history").insert(rows);
        if(ins.error)return h({error:ins.error.message},500);
      }
    }

    const earned=String(t.end_date||t.start_date);
    let rank:any={data:null,error:null};
    let juniorDoubleRank:any=null;
    if(isJuniorDouble){
      const currentA=Number(anthony.junior_doubles_game_points||0);
      const currentB=Number(partner.junior_doubles_game_points||0);
      const [ua,ub]=await Promise.all([
        db.from("players").update({junior_doubles_game_points:currentA+pts}).eq("id",anthony.id),
        db.from("players").update({junior_doubles_game_points:currentB+Math.round(pts*.85)}).eq("id",partner.id)
      ]);
      if(ua.error||ub.error)return h({error:(ua.error||ub.error)?.message},500);
      const rr=await db.rpc("refresh_junior_doubles_ranking",{p_snapshot:earned});
      if(rr.error)return h({error:rr.error.message},500);
      const fresh=await db.from("players").select("junior_doubles_ranking,junior_doubles_points").eq("id",anthony.id).maybeSingle();
      if(fresh.error)return h({error:fresh.error.message},500);
      juniorDoubleRank=fresh.data;
    }else{
      const exp=new Date(earned+"T12:00:00Z");exp.setUTCDate(exp.getUTCDate()+364);
      await db.from("user_doubles_points").insert({owner_id:"demo",player_id:Number(anthony.id),tournament_id:tid,partner_id:partner.id,label:t.name,earned_date:earned,expiry_date:exp.toISOString().slice(0,10),points:pts,active:true});
      rank=await db.rpc("recalculate_managed_player_doubles_ranking",{p_player_id:Number(anthony.id),p_date:earned});
      if(rank.error)return h({error:rank.error.message},500);
    }
    let staffAchievementCredits:any[]=[];
    if(userRound==="Champion"){
      const [titleA,titleB]=await Promise.all([
        db.from("player_titles").insert({
          player_id:anthony.id,tournament_name:t.name,title_date:earned,
          level:String(t.category||t.level||t.circuit||"Double"),surface:String(t.surface||""),
          event_type:isJuniorDouble?"junior_doubles":"doubles",partner_player_id:partner.id,partner_name:partner.name,
          verified:false,source_label:isJuniorDouble?"Court Boss · titre junior double simulé":"Court Boss · carrière simulée",origin:"game"
        }).select("id").single(),
        db.from("player_titles").insert({
          player_id:partner.id,tournament_name:t.name,title_date:earned,
          level:String(t.category||t.level||t.circuit||"Double"),surface:String(t.surface||""),
          event_type:isJuniorDouble?"junior_doubles":"doubles",partner_player_id:anthony.id,partner_name:anthony.name,
          verified:false,source_label:isJuniorDouble?"Court Boss · titre junior double simulé":"Court Boss · carrière simulée",origin:"game"
        }).select("id").single()
      ]);
      const titleErr=titleA.error||titleB.error;
      if(titleErr)return h({error:titleErr.message},500);
      const [creditA,creditB]=await Promise.all([
        db.rpc("credit_staff_title",{p_player_title_id:Number(titleA.data.id)}),
        db.rpc("credit_staff_title",{p_player_title_id:Number(titleB.data.id)})
      ]);
      staffAchievementCredits=[
        creditA.error?{error:creditA.error.message}:creditA.data,
        creditB.error?{error:creditB.error.message}:creditB.data
      ];
    }

    const finalUserMatch=matches.filter((m:any)=>m.user_pair===userPair.name).find((m:any)=>m.round_name==="F")||null;
    let hiddenTraitEvolution:any=null;
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
      const hidden=await db.rpc("evolve_player_hidden_traits_from_results",{p_from_date:earned,p_to_date:earned});
      hiddenTraitEvolution=hidden.error?{error:hidden.error.message}:hidden.data;
    }

    const singlesRun=await db.from("tournament_runs").select("id").eq("tournament_id",tid).eq("managed_player_id",Number(anthony.id)).maybeSingle();
    const travelCost=singlesRun.data?0:(String(t.country||"")===String(c.country||"FRA")?80:260);
    const fatigueAdd=matches.filter((m:any)=>m.user_pair===userPair.name).length*4+(travelCost?3:0);
    const agentRep=await db.from("player_agency_representation").select("commission_pct").eq("player_id",anthony.id).eq("active",true).maybeSingle();
    const agentCommission=Math.max(0,Math.round(prizeEur*Math.min(20,Number(agentRep.data?.commission_pct||0))/100));
    let staffPerformanceBonus=0;
    if(userRound==="Champion"){
      const staffContracts=await db.from("contracts").select("weekly_salary,bonuses").eq("subject_type","staff").eq("status","active");
      const titleBonusMult=/Grand Chelem|Grand Slam/i.test(String(t.category||t.level||""))?3:/Masters 1000/i.test(String(t.category||t.level||""))?2:1;
      if(!staffContracts.error){
        staffPerformanceBonus=(staffContracts.data??[]).reduce((sum:number,x:any)=>{
          const demands=x.bonuses?.demands||{};
          return sum+(demands.performance_bonus?Math.round(Number(x.weekly_salary||0)*titleBonusMult):0);
        },0);
      }
    }
    const newBudget=Number(c.budget||0)+prizeEur-travelCost-agentCommission-staffPerformanceBonus;
    const newFatigue=Math.min(100,Number(c.fatigue||18)+fatigueAdd);
    const newFitness=Math.max(35,Number(c.fitness||91)-Math.ceil(fatigueAdd*.35));
    const careerUpdate:any={budget:newBudget,updated_at:new Date().toISOString()};
    if(Number(anthony.id)===primaryManagedId){
      careerUpdate.fatigue=newFatigue;
      careerUpdate.fitness=newFitness;
      if(!isJuniorDouble){
        careerUpdate.doubles_rank=Number(rank.data?.rank||c.doubles_rank);
        careerUpdate.doubles_points=Number(rank.data?.points||c.doubles_points);
      }
    }
    const playerDoubleUpdate:any={fatigue:newFatigue,fitness:newFitness};
    if(!isJuniorDouble){
      playerDoubleUpdate.doubles_ranking=rank.data?.rank??anthony.doubles_ranking??null;
      playerDoubleUpdate.doubles_points=Number(rank.data?.points??anthony.doubles_points??0);
      playerDoubleUpdate.doubles_snapshot_date=earned;
      playerDoubleUpdate.doubles_source="Court Boss managed squad · player scoped doubles ledger";
    }
    await Promise.all([
      db.from("career_state").update(careerUpdate).eq("id","demo"),
      db.from("players").update(playerDoubleUpdate).eq("id",Number(anthony.id))
    ]);
    const finState=await db.from("finances").select("prize_money,travel_cost,agent_commission,staff_bonus").eq("id","demo").maybeSingle();
    if(!finState.error){
      await db.from("finances").update({
        prize_money:Number(finState.data?.prize_money||0)+prizeEur,
        travel_cost:Number(finState.data?.travel_cost||0)+travelCost,
        agent_commission:Number(finState.data?.agent_commission||0)+agentCommission,
        staff_bonus:Number(finState.data?.staff_bonus||0)+staffPerformanceBonus
      }).eq("id","demo");
    }
    await db.from("news_items").insert({body:userRound==="Champion"?String(anthony.name||c.player_name||"Le joueur")+" et "+partner.name+" remportent le double à "+t.name+" !":String(anthony.name||c.player_name||"Le joueur")+" et "+partner.name+" terminent "+userRound+" en double à "+t.name+"."});
    await recordFinanceTransactions([
      {transaction_key:"doubles-run:"+run.data.id+":prize",game_date:earned,week:Number(c.week||0)||null,category:"prize_money",amount:prizeEur,source_type:"doubles_run",source_id:Number(run.data.id),description:"Prize money double · "+String(t.name),metadata:{result:userRound,partner_id:partner.id}},
      {transaction_key:"doubles-run:"+run.data.id+":travel",game_date:earned,week:Number(c.week||0)||null,category:"travel",amount:-travelCost,source_type:"doubles_run",source_id:Number(run.data.id),description:"Voyage double · "+String(t.name)},
      {transaction_key:"doubles-run:"+run.data.id+":agent",game_date:earned,week:Number(c.week||0)||null,category:"agent_commission",amount:-agentCommission,source_type:"doubles_run",source_id:Number(run.data.id),description:"Commission agent double · "+String(t.name)},
      {transaction_key:"doubles-run:"+run.data.id+":staff-bonus",game_date:earned,week:Number(c.week||0)||null,category:"staff_bonus",amount:-staffPerformanceBonus,source_type:"doubles_run",source_id:Number(run.data.id),description:"Prime performance staff double · "+String(t.name),balance_after:newBudget}
    ]);

    const pairDynamics=await db.rpc("apply_managed_doubles_result",{p_run_id:Number(run.data.id),p_date:earned});
    if(persistedDoubleEntry?.id){
      const playedEntry=await db.from("managed_doubles_entries").update({
        status:"played",
        metadata:{
          ...(persistedDoubleEntry.metadata||{}),
          played_run_id:Number(run.data.id),
          played_on:earned,
          result:userRound,
          entry_method:doublesRunEntryMethod
        },
        updated_at:new Date().toISOString()
      }).eq("id",Number(persistedDoubleEntry.id));
      if(playedEntry.error)return h({error:playedEntry.error.message},500);
    }
    const board=await db.rpc("update_board_state");
    return h({ok:true,run_id:run.data.id,managed_player_id:Number(anthony.id),managed_player_name:String(anthony.name||""),tournament:t,partner:{id:partner.id,name:partner.name},round:userRound,points:pts,prize,prize_eur:prizeEur,prize_fx_rate_to_eur:prizeFxRateToEur,base_currency:BASE_CURRENCY,rank:isJuniorDouble?juniorDoubleRank?.junior_doubles_ranking:rank.data?.rank,total_points:isJuniorDouble?juniorDoubleRank?.junior_doubles_points:rank.data?.points,ranking_kind:isJuniorDouble?"junior_doubles":"atp_doubles",doubles_entry_status:doublesEntryStatus,entry_method:doublesRunEntryMethod,qualifying_points:qualifyingPointsEarned,protected_ranking_use:protectedDoubleUse,fatigue_added:fatigueAdd,travel_cost:travelCost,agent_commission:agentCommission,staff_performance_bonus:staffPerformanceBonus,staff_achievement_credits:staffAchievementCredits,hidden_trait_evolution:hiddenTraitEvolution,pair_dynamics:pairDynamics.error?{error:pairDynamics.error.message}:pairDynamics.data,matches:matches.filter((m:any)=>m.user_pair===userPair.name),board:board.data});
  }

  if(path.endsWith("/api/season-summary")&&req.method==="GET"){
    const requestedPlayerId=n(u.searchParams.get("player_id"),0,0,99999999);
    const career=await db.from("career_state").select("*").eq("id","demo").maybeSingle();
    if(career.error||!career.data)return h({error:career.error?.message||"Career missing"},500);
    const primaryId=Number(career.data.managed_player_id||0);
    const playerId=Number(requestedPlayerId||primaryId||0);
    if(!playerId)return h({error:"Joueur géré introuvable"},404);
    if(playerId!==primaryId){
      const roster=await db.from("academy_roster").select("id").eq("player_id",playerId).eq("status","active").maybeSingle();
      if(roster.error)return h({error:roster.error.message},500);
      if(!roster.data)return h({error:"Ce joueur ne fait pas partie du groupe géré."},403);
    }
    const player=await db.from("players")
      .select("id,name,country,ranking,points,doubles_ranking,doubles_points,form,fitness,morale,fatigue,career_focus")
      .eq("id",playerId).maybeSingle();
    if(player.error||!player.data)return h({error:player.error?.message||"Joueur introuvable"},404);

    const [singles,doubles,pts,dpts,matches]=await Promise.all([
      db.from("tournament_runs").select("*,tournaments(*)").eq("managed_player_id",playerId).order("played_at",{ascending:false}).limit(100),
      db.from("doubles_runs").select("*,tournaments(*),partner:players(id,name,country)").eq("managed_player_id",playerId).order("played_at",{ascending:false}).limit(100),
      db.from("user_ranking_points").select("*").eq("owner_id","demo").eq("player_id",playerId).order("earned_date",{ascending:false}),
      db.from("user_doubles_points").select("*").eq("owner_id","demo").eq("player_id",playerId).order("earned_date",{ascending:false}),
      db.from("match_history").select("*").eq("user_involved",true).order("match_date",{ascending:false}).limit(500)
    ]);
    const err=singles.error||doubles.error||pts.error||dpts.error||matches.error;
    if(err)return h({error:err.message},500);
    const s=singles.data??[],d=doubles.data??[];
    const playerName=String(player.data.name||"Joueur");
    const mh=(matches.data??[]).filter((x:any)=>{
      const mid=Number(x.managed_player_id||0);
      if(mid)return mid===playerId;
      return String(x.player_a||"")===playerName||String(x.player_b||"")===playerName;
    });
    const careerView={
      ...career.data,
      managed_player_id:playerId,
      player_name:player.data.name,
      country:player.data.country,
      singles_rank:player.data.ranking,
      points:player.data.points,
      doubles_rank:player.data.doubles_ranking,
      doubles_points:player.data.doubles_points,
      form:player.data.form,
      fitness:player.data.fitness,
      morale:player.data.morale,
      fatigue:player.data.fatigue,
      career_focus:player.data.career_focus
    };
    return h({
      player_id:playerId,
      career:careerView,
      singles:s,
      doubles:d,
      singles_points:pts.data??[],
      doubles_points:dpts.data??[],
      stats:{
        tournaments:s.length+d.length,
        singles_tournaments:s.length,
        doubles_tournaments:d.length,
        titles:s.filter((x:any)=>x.user_round==="Champion").length,
        singles_titles:s.filter((x:any)=>x.user_round==="Champion").length,
        doubles_titles:d.filter((x:any)=>x.user_round==="Champion").length,
        total_titles:s.filter((x:any)=>x.user_round==="Champion").length+d.filter((x:any)=>x.user_round==="Champion").length,
        finals:s.filter((x:any)=>["F","Champion"].includes(String(x.user_round))).length,
        singles_finals:s.filter((x:any)=>["F","Champion"].includes(String(x.user_round))).length,
        doubles_finals:d.filter((x:any)=>["F","Champion"].includes(String(x.user_round))).length,
        prize:s.reduce((a:number,x:any)=>a+Number(x.user_prize||0),0)+d.reduce((a:number,x:any)=>a+Number(x.user_prize||0),0),
        matches:mh.length,
        wins:mh.filter((x:any)=>String(x.winner||"")===playerName).length
      }
    });
  }

  if(path.endsWith("/api/schedule-advice")&&req.method==="GET"){
    const requestedPlayerId=n(u.searchParams.get("player_id"),0,0,99999999);
    const career=await db.from("career_state").select("*").eq("id","demo").maybeSingle();
    if(career.error||!career.data)return h({error:career.error?.message||"Career missing"},500);
    const primaryId=Number(career.data.managed_player_id||0);
    const playerId=Number(requestedPlayerId||primaryId||0);
    if(!playerId)return h({error:"Joueur géré introuvable"},404);
    if(playerId!==primaryId){
      const roster=await db.from("academy_roster").select("id").eq("player_id",playerId).eq("status","active").maybeSingle();
      if(roster.error)return h({error:roster.error.message},500);
      if(!roster.data)return h({error:"Ce joueur ne fait pas partie du groupe géré."},403);
    }
    const player=await db.from("players")
      .select("id,name,country,ranking,doubles_ranking,form,fitness,fatigue,career_focus,player_attributes(*)")
      .eq("id",playerId).maybeSingle();
    if(player.error||!player.data)return h({error:player.error?.message||"Joueur introuvable"},404);
    const attrs:any=Array.isArray(player.data.player_attributes)?player.data.player_attributes[0]:player.data.player_attributes||{};
    const c:any={
      ...career.data,
      managed_player_id:playerId,
      player_name:player.data.name,
      country:player.data.country,
      singles_rank:Number(player.data.ranking??career.data.singles_rank??30000),
      doubles_rank:Number(player.data.doubles_ranking??career.data.doubles_rank??3000),
      form:Number(player.data.form??career.data.form??70),
      fitness:Number(player.data.fitness??career.data.fitness??90),
      fatigue:Number(player.data.fatigue??career.data.fatigue??18),
      career_focus:String(player.data.career_focus||career.data.career_focus||"mixed")
    };
    const tours=await db.from("tournaments").select("*").eq("is_active",true).in("circuit",["ATP","Challenger","ITF"]).gte("start_date",c.career_date).order("start_date",{ascending:true}).limit(180);
    if(tours.error)return h({error:tours.error.message},500);
    const european=["FRA","ESP","ITA","GER","GBR","CZE","AUT","SUI","BEL","NED","POR","MON","NOR","SWE","DEN","POL","SRB","CRO","GRE"];
    const focus=String(c.career_focus||"mixed");
    const doublesOnly=focus==="doubles_only";
    const singlesOnly=focus==="singles_only";
    const score=(t:any)=>{
      const direct=Number(t.direct_cut??t.projected_direct_cut??0),qual=Number(t.qual_cut??t.projected_qual_cut??0);
      const singlesCut=direct&&c.singles_rank<=direct?30:qual&&c.singles_rank<=qual?18:qual&&c.singles_rank<=qual+50?8:-10;
      const doublesRank=Number(c.doubles_rank||99999);
      const doublesAccess=t.doubles?(doublesRank<=50?28:doublesRank<=150?22:doublesRank<=400?15:doublesRank<=900?8:2):-35;
      const cut=doublesOnly?doublesAccess:singlesCut;
      const surf=t.surface==="Terre"?Number(attrs.clay_affinity||10):t.surface==="Gazon"?Number(attrs.grass_affinity||10):Number(attrs.hard_affinity||10);
      const travel=t.country===c.country?10:european.includes(t.country)?5:-3;
      const fatigue=Number(c.fatigue||18)>55?-18:Number(c.fatigue||18)>35?-8:7;
      const level=doublesOnly
        ?(/Grand Chelem|Masters 1000/i.test(String(t.category||""))?4:/ATP 500|ATP 250/i.test(String(t.category||""))?7:/Challenger/i.test(String(t.category||""))?10:5)
        :(/Grand Chelem|Masters 1000/i.test(String(t.category||""))?-8:/ATP 500|ATP 250/i.test(String(t.category||""))?0:/Challenger/i.test(String(t.category||""))?10:6);
      const sourceBonus=t.is_verified?8:-2;
      return Math.max(0,Math.min(100,40+cut+surf+travel+fatigue+level+sourceBonus));
    };
    const rows=(tours.data??[])
      .filter((t:any)=>doublesOnly?Boolean(t.doubles):singlesOnly?Boolean(t.singles):true)
      .map((t:any)=>({...t,recommendation_score:score(t),career_focus:focus,managed_player_id:playerId}))
      .sort((x:any,y:any)=>y.recommendation_score-x.recommendation_score);
    return h({
      player_id:playerId,
      career:{player_name:c.player_name,rank:doublesOnly?c.doubles_rank:c.singles_rank,singles_rank:c.singles_rank,doubles_rank:c.doubles_rank,career_focus:c.career_focus,fatigue:c.fatigue,fitness:c.fitness},
      recommended:rows.slice(0,12)
    });
  }


  if(path.endsWith("/api/season-history")&&req.method==="GET"){
    const {data,error}=await db.from("season_history").select("*").order("season_year",{ascending:false}).limit(20);
    return error?h({error:error.message},500):h({rows:data??[]});
  }

  if(path.endsWith("/api/rollover-season")&&req.method==="POST"){
    let body:any;try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const newYear=n(body?.new_year,new Date().getFullYear()+1,2027,9999);
    const current=await db.from("career_state").select("season_year,career_date").eq("id","demo").maybeSingle();
    if(current.error||!current.data)return h({error:current.error?.message||"Career missing"},500);
    if(newYear<=Number(current.data.season_year||2025))return h({error:"La nouvelle saison doit être supérieure à la saison actuelle."},409);
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

    const rolloverManagedRankings:any[]=[];
    const rollCareer=await db.from("career_state").select("managed_player_id").eq("id","demo").maybeSingle();
    const rollRoster=await db.from("academy_roster").select("player_id").eq("status","active").not("player_id","is",null);
    if(rollCareer.error||rollRoster.error)return h({error:(rollCareer.error||rollRoster.error)?.message},500);
    const rollPrimaryId=Number(rollCareer.data?.managed_player_id||0);
    for(const row of rollRoster.data??[]){
      const pid=Number((row as any).player_id||0);
      if(!pid||pid===rollPrimaryId)continue;
      const rr=await db.rpc("recalculate_managed_player_ranking",{p_player_id:pid,p_date:String(newYear)+"-01-05",p_sync_career:false});
      if(rr.error)return h({error:"Recalcul annuel joueur "+String(pid)+" : "+rr.error.message},500);
      rolloverManagedRankings.push(rr.data);
    }
    return h({ok:true,rollover:roll.data,userRanking:rank.data,managedPlayerRankings:rolloverManagedRankings,userDoublesRanking:doubleRank.data});
  }


  // CB-MATCH-ENGINE-v2 · deterministic match-day environment + tournament identity.
  const liveMatchHash=(value:string)=>{
    let h=2166136261;
    for(let i=0;i<value.length;i++){h^=value.charCodeAt(i);h=Math.imul(h,16777619)}
    return Math.abs(h>>>0);
  };
  const liveFormModifier=(value:any)=>{
    const form=Math.max(0,Math.min(100,Number(value??70)));
    if(form>=92)return 3;
    if(form>=82)return 2;
    if(form>=72)return 1;
    if(form>=55)return 0;
    if(form>=45)return -1;
    if(form>=35)return -2;
    return -3;
  };
  const buildLiveMatchEnvironment=(t:any,managed:any,opp:any,gameDate:string,surfaceOverride?:string)=>{
    const rawSurface=String(surfaceOverride||t?.surface||"Dur");
    const indoor=Boolean(t?.indoor)||/intérieur|indoor/i.test(rawSurface)||/indoor/i.test(String(t?.environment_profile||t?.environment||""));
    const surface=rawSurface==="Dur"&&indoor?"Dur intérieur":rawSurface;
    const seed=liveMatchHash([t?.id||0,managed?.id||0,opp?.id||0,gameDate,surface].join("|"));
    const unit=(shift:number)=>((seed>>>shift)%1000)/999;
    const clay=/terre|clay/i.test(surface),grass=/gazon|grass/i.test(surface);
    const baseSpeed=Number(t?.court_speed??(clay?.72:grass?1.18:indoor?1.12:1.0));
    const altitude=Math.max(0,Number(t?.altitude_m||0));
    let temperature=indoor?21:Math.round((clay?24:grass?19:23)+(unit(1)-.5)*12);
    let humidity=indoor?48:Math.round(42+unit(6)*38);
    let windKph=indoor?0:Math.round(unit(11)*26);
    let condition=indoor?"Indoor climatisé":windKph>=19?"Venteux":humidity>=72?"Humide":temperature>=29?"Chaud":unit(16)>.66?"Nuageux":"Dégagé";
    const heat=Math.max(0,temperature-26);
    const weatherDifficulty=Math.min(20,windKph*.35+heat*.45+Math.max(0,humidity-68)*.12);
    const mood=(p:any,home:boolean)=>Math.round(Math.max(25,Math.min(95,
      Number(p?.morale??72)*.42+Number(p?.form??70)*.28+Number(p?.fitness??88)*.22-Number(p?.fatigue??18)*.16
      +(home?4:0)-weatherDifficulty*.35+22
    )));
    const homeUser=Boolean(t?.country&&managed?.country&&String(t.country)===String(managed.country));
    const homeOpp=Boolean(t?.country&&opp?.country&&String(t.country)===String(opp.country));
    const userForm=Math.max(0,Math.min(100,Number(managed?.form??70)));
    const oppForm=Math.max(0,Math.min(100,Number(opp?.form??70)));
    const userFormBonus=liveFormModifier(userForm),oppFormBonus=liveFormModifier(oppForm);
    const grandSlam=Boolean(t&&String(t.circuit||"")==="ATP"&&/Grand Chelem|Grand Slam/i.test(String(t.category||"")));
    const setsToWin=grandSlam?3:2;
    return {
      engine:"CB-MATCH-ENGINE-v3",
      surface,indoor,sets_to_win:setsToWin,best_of:setsToWin*2-1,
      court_speed:Number(baseSpeed.toFixed(3)),altitude_m:altitude,
      weather:{condition,temperature_c:temperature,humidity_pct:humidity,wind_kph:windKph,weather_difficulty:Number(weatherDifficulty.toFixed(1))},
      mood:{user:mood(managed,homeUser),opponent:mood(opp,homeOpp),home_user:homeUser,home_opponent:homeOpp},
      form:{user:userForm,opponent:oppForm,user_bonus:userFormBonus,opponent_bonus:oppFormBonus,scale:"all_match_attributes",min:-3,max:3},
      tournament:t?{
        id:Number(t.id),name:String(t.name||"Tournoi"),city:t.city||null,country:t.country||null,
        venue:t.venue||null,circuit:t.circuit||null,category:t.category||null,
        logo_url:t.logo_url||null,image_url:t.image_url||null,
        environment:t.environment_profile||t.environment||(indoor?"Indoor":"Outdoor"),
        start_date:t.start_date||null,end_date:t.end_date||null
      }:null
    };
  };

  if(path.endsWith("/api/live-match/start")&&req.method==="POST"){
    let body:any;try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const tactics=body?.tactics||{};
    const requestedPlayerId=n(body?.player_id,0,0,99999999);
    const tournamentId=n(body?.tournament_id,0,0,99999999);
    const requestedRound=String(body?.round||"").slice(0,40);

    const career=await db.from("career_state")
      .select("managed_player_id,singles_rank,player_name,career_focus,career_date")
      .eq("id","demo").maybeSingle();
    if(career.error||!career.data)return h({error:career.error?.message||"Career missing"},500);

    const primaryId=Number(career.data.managed_player_id||0);
    const playerId=Number(requestedPlayerId||primaryId||0);
    if(!playerId)return h({error:"Joueur géré introuvable"},404);

    if(playerId!==primaryId){
      const roster=await db.from("academy_roster")
        .select("id").eq("player_id",playerId).eq("status","active").maybeSingle();
      if(roster.error)return h({error:roster.error.message},500);
      if(!roster.data)return h({error:"Ce joueur ne fait pas partie du groupe géré."},403);
    }

    const [managed,activeInjury,tournament]=await Promise.all([
      db.from("players")
        .select("id,name,country,ranking,career_focus,current_ability,form,fitness,fatigue,morale")
        .eq("id",playerId).maybeSingle(),
      db.from("injuries")
        .select("id,injury_type,severity,expected_return,aggravation_risk,status")
        .eq("player_id",playerId).eq("status","Active")
        .order("started_at",{ascending:false}).limit(1).maybeSingle(),
      tournamentId
        ?db.from("tournaments").select("id,name,city,country,surface,indoor,venue,circuit,category,logo_url,image_url,court_speed,altitude_m,environment,environment_profile,start_date,end_date,singles_draw_size,draw_size").eq("id",tournamentId).maybeSingle()
        :Promise.resolve({data:null,error:null} as any)
    ]);
    if(managed.error||activeInjury.error||tournament.error)return h({error:(managed.error||activeInjury.error||tournament.error)?.message},500);
    if(!managed.data)return h({error:"Joueur géré introuvable"},404);
    if(tournamentId&&!tournament.data)return h({error:"Tournoi introuvable"},404);

    if(activeInjury.data){
      return h({
        error:String(managed.data.name||"Ce joueur")+" est indisponible : "+String(activeInjury.data.injury_type||"blessure active")+".",
        injured:true,player_id:playerId,injury:activeInjury.data
      },409);
    }

    const playerFocus=String(managed.data.career_focus||(playerId===primaryId?career.data.career_focus:"mixed")||"mixed");
    if(playerFocus==="doubles_only"){
      return h({
        error:"Orientation Double exclusivement : le Match Center simple est désactivé pour ce joueur.",
        doubles_only:true,player_id:playerId
      },409);
    }

    let opponentId=Number(body?.opponent_id||0);
    const rank=Math.max(1,Number(managed.data.ranking??(playerId===primaryId?career.data.singles_rank:500)??500));

    if(!opponentId&&tournamentId){
      const accepted=await db.from("world_tournament_acceptance_entries")
        .select("player_id,effective_rank,status,entry_method")
        .eq("tournament_id",tournamentId).in("status",["accepted","promoted"])
        .order("effective_rank",{ascending:true}).limit(256);
      if(accepted.error)return h({error:accepted.error.message},500);
      const pool=(accepted.data??[])
        .filter((x:any)=>Number(x.player_id)&&Number(x.player_id)!==playerId)
        .sort((x:any,y:any)=>Math.abs(Number(x.effective_rank||9999)-rank)-Math.abs(Number(y.effective_rank||9999)-rank));
      opponentId=Number(pool[0]?.player_id||0);
    }
    if(!opponentId){
      const lo=Math.max(1,rank-14),hi=rank+14;
      const candidates=await db.from("players")
        .select("id,name,country,ranking")
        .eq("ranking_current",true)
        .gte("ranking",lo).lte("ranking",hi)
        .order("ranking",{ascending:true}).limit(40);
      if(candidates.error)return h({error:candidates.error.message},500);
      const pool=(candidates.data??[]).filter((x:any)=>Number(x.id)!==playerId);
      const pick=pool.length?pool[(liveMatchHash(String(career.data.career_date)+"|"+playerId+"|"+(tournamentId||0)))%pool.length]:null;
      opponentId=Number(pick?.id||0);
    }
    if(!opponentId)return h({error:"Aucun adversaire disponible autour du classement de ce joueur."},404);
    if(opponentId===playerId)return h({error:"Le joueur ne peut pas s’affronter lui-même."},409);

    const opp=await db.from("players")
      .select("id,name,country,ranking,current_ability,form,fitness,fatigue,morale,style,player_attributes(*)")
      .eq("id",opponentId).maybeSingle();
    if(opp.error||!opp.data)return h({error:opp.error?.message||"Adversaire introuvable"},404);

    const surfaceRaw=String(tournament.data?.surface||body?.surface||"Dur").slice(0,30);
    const surface=surfaceRaw==="Dur"&&tournament.data?.indoor?"Dur intérieur":surfaceRaw;
    const environment=buildLiveMatchEnvironment(tournament.data,managed.data,opp.data,String(career.data.career_date||AGE_REFERENCE_DATE),surface);
    let round=requestedRound||"Exhibition";
    if(tournamentId&&!requestedRound){
      const entry=await db.from("entries").select("entry_method").eq("tournament_id",tournamentId).eq("player_id",playerId).order("id",{ascending:false}).limit(1).maybeSingle();
      if(entry.error)return h({error:entry.error.message},500);
      const method=String(entry.data?.entry_method||"direct");
      if(method==="qualifying"||method==="protected_qualifying"||method.endsWith("_qualifying"))round="Q1";
      else round="R"+String(Math.max(8,Number(tournament.data?.singles_draw_size||tournament.data?.draw_size||32)));
    }
    const baseStats:any={
      user_winners:0,user_errors:0,user_aces:0,opp_winners:0,opp_errors:0,
      user_double_faults:0,opp_double_faults:0,
      user_first_serves:0,user_first_serves_in:0,opp_first_serves:0,opp_first_serves_in:0,
      user_unreturned_serves:0,opp_unreturned_serves:0,
      _meta:{...environment,round,career_date:String(career.data.career_date||AGE_REFERENCE_DATE)}
    };

    const ins=await db.from("live_match_sessions").insert({
      managed_player_id:playerId,tournament_id:tournamentId||null,
      opponent_id:opponentId,surface:environment.surface,status:"active",user_sets:0,opponent_sets:0,set_no:1,
      user_games:0,opponent_games:0,user_points:0,opponent_points:0,serving_user:true,rally_no:0,
      momentum:50,tactics,stats:baseStats,score_log:[],last_point:{}
    }).select("*").single();
    if(ins.error)return h({error:ins.error.message},500);

    return h({
      ok:true,engine:"CB-MATCH-ENGINE-v2",
      managed_player_id:playerId,
      managed_player:{id:managed.data.id,name:managed.data.name,country:managed.data.country,ranking:managed.data.ranking},
      session:ins.data,match_environment:environment,
      opponent:{id:opp.data.id,name:opp.data.name,country:opp.data.country,ranking:opp.data.ranking}
    });
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

    const career=await db.from("career_state").select("*").eq("id","demo").maybeSingle();
    if(career.error||!career.data)return h({error:career.error?.message||"Données match incomplètes"},500);
    const livePlayerId=Number(session.data.managed_player_id||career.data.managed_player_id||0);
    const [managed,opp]=await Promise.all([
      db.from("players").select("id,name,country,current_ability,form,fitness,fatigue,morale,player_attributes(*)").eq("id",livePlayerId).maybeSingle(),
      db.from("players").select("id,name,country,ranking,current_ability,form,fitness,fatigue,style,player_attributes(*)").eq("id",session.data.opponent_id).maybeSingle()
    ]);
    const err=managed.error||opp.error;
    if(err||!managed.data||!opp.data)return h({error:err?.message||"Données match incomplètes"},500);
    const isPrimaryLive=livePlayerId===Number(career.data.managed_player_id||0);

    const tactics=body?.tactics||session.data.tactics||{};
    const ag=n(tactics.aggression,58,1,100),risk=n(tactics.risk,52,1,100),net=n(tactics.net,28,1,100);
    const ret=String(tactics.returnPos||"Neutre");
    const surface=String(session.data.surface||"Dur");
    const key=surface==="Terre"?"clay_affinity":surface==="Gazon"?"grass_affinity":"hard_affinity";
    const ua:any=Array.isArray(managed.data.player_attributes)?managed.data.player_attributes[0]:managed.data.player_attributes||{};
    const oa:any=Array.isArray(opp.data.player_attributes)?opp.data.player_attributes[0]:opp.data.player_attributes||{};

    const attrEdge=(x:any)=>{
      const avg=(keys:string[])=>keys.reduce((s,k)=>s+Number(x?.[k]??10),0)/Math.max(1,keys.length);
      const mental=avg(["decision_making","shot_selection","consistency","big_points","killer_instinct","fighting_spirit","determination","patience","tenacity"]);
      const firstStrike=avg(["serve_power","serve_precision","first_serve_quality","second_serve_quality","serve_variety","serve_spin","serve_consistency","serve_plus_one"]);
      const ground=avg(["forehand","forehand_power","forehand_accuracy","forehand_consistency","backhand","backhand_power","backhand_accuracy","backhand_consistency","topspin","slice","shot_control","timing"]);
      const defense=avg(["return_game","return_aggression","return_consistency","reaction","passing_shot","defensive_skill","transition_game","court_positioning","defense_to_attack","counter_skill"]);
      const athletic=avg(["movement","speed","strength","acceleration","agility","balance","natural_fitness","recovery","flexibility","rally_tolerance","footwork","athleticism","work_rate"]);
      const netSkill=avg(["volley","touch","half_volley","smash","lob","net_positioning","transition_game","reaction"]);
      return (mental-10)*.18+(firstStrike-10)*.14+(ground-10)*.12+(defense-10)*.11+(athletic-10)*.07+(netSkill-10)*.07;
    };
    const uBase=Number(managed.data.current_ability||56)+Number(managed.data.form||70)*.14+Number(managed.data.fitness||90)*.06-Number(managed.data.fatigue||20)*.11+Number(ua[key]||10)*.62+attrEdge(ua);
    const oBase=Number(opp.data.current_ability||55)+Number(opp.data.form||70)*.14+Number(opp.data.fitness||90)*.06-Number(opp.data.fatigue||20)*.11+Number(oa[key]||10)*.62+attrEdge(oa);
    const balance=2.8-Math.abs(ag-62)*.025-Math.abs(risk-55)*.02;
    const netBonus=(surface==="Gazon"?.035:surface.toLowerCase().includes("intérieur")?.028:surface.startsWith("Dur")?.018:.006)*net;
    const retBonus=ret==="Avancée"?1.4:ret==="Reculée"?.7:1.0;
    const momentum=(Number(session.data.momentum||50)-50)*.045;
    const netQuality=((Number(ua.volley||10)+Number(ua.net_positioning||10)+Number(ua.transition_game||10)+Number(ua.half_volley||10)+Number(ua.smash||10)+Number(ua.reaction||10))/6
      -(Number(oa.passing_shot||10)+Number(oa.reaction||10)+Number(oa.defensive_skill||10))/3);
    const returnRead=(ret==="Avancée"
      ?(Number(ua.reaction||10)+Number(ua.return_aggression||10)-Number(oa.first_serve_quality||10)-Number(oa.serve_power||10))*.045
      :ret==="Reculée"
        ?(Number(ua.return_consistency||10)+Number(ua.rally_tolerance||10)-Number(oa.serve_plus_one||10)-18)*.035
        :0);
    const pressureEdge=((Number(ua.big_points||10)+Number(ua.composure||10)+Number(ua.decision_making||10))
      -(Number(oa.big_points||10)+Number(oa.composure||10)+Number(oa.decision_making||10)))/18;
    const uConsistency=Math.max(1,Math.min(20,Number(ua.consistency||10)));
    const oConsistency=Math.max(1,Math.min(20,Number(oa.consistency||10)));
    const uSwing=(Math.random()-.5)*Math.max(.7,4.2-uConsistency*.16);
    const oSwing=(Math.random()-.5)*Math.max(.7,4.2-oConsistency*.16);
    const uStrength=uBase+balance+netBonus+retBonus+momentum+netQuality*(net/100)*.16+returnRead+uSwing;
    const oStrength=oBase+oSwing;
    const close=Math.abs(uStrength-oStrength)<7;
    const pressureBonus=close?pressureEdge*.30:0;
    const prob=1/(1+Math.exp(-((uStrength+pressureBonus)-oStrength)/7));
    const userWon=Math.random()<prob;
    const setScore=userWon?(close?(Math.random()<.5?"7-6":"7-5"):(Math.random()<.5?"6-3":"6-4")):(close?(Math.random()<.5?"6-7":"5-7"):(Math.random()<.5?"3-6":"4-6"));

    const setStats={
      first_serve_pct:Math.max(42,Math.min(82,44+Number(ua.serve_precision||10)*.82+Number(ua.serve_consistency||10)*.62+Number(ua.timing||10)*.22-Math.round((risk-50)*.10)+Math.round(Math.random()*6-3))),
      winners:Math.max(6,Math.round(5+ag*.075+risk*.035+(Number(ua.forehand_power||10)+Number(ua.backhand_power||10)+Number(ua.killer_instinct||10)+Number(ua.timing||10))*.16+Math.random()*5)),
      unforced_errors:Math.max(3,Math.round(15+risk*.07+ag*.018-(Number(ua.consistency||10)+Number(ua.shot_selection||10)+Number(ua.shot_control||10)+Number(ua.forehand_consistency||10)+Number(ua.backhand_consistency||10)+Number(ua.timing||10))*.20+Math.random()*4)),
      aces:Math.max(0,Math.round(Number(ua.serve_power||10)*.14+Number(ua.first_serve_quality||10)*.10+Number(ua.serve_variety||10)*.08+Number(ua.serve_spin||10)*.06+Math.random()*2.2)),
      net_points_won_pct:Math.max(30,Math.min(90,37+Math.round(net*.15)+Math.round((Number(ua.volley||10)+Number(ua.half_volley||10)+Number(ua.smash||10)+Number(ua.net_positioning||10)+Number(ua.transition_game||10)+Number(ua.reaction||10)-60)*.38)-Math.round((Number(oa.passing_shot||10)+Number(oa.reaction||10)+Number(oa.lob||10)-30)*.28)+Math.round(Math.random()*7-3))),
      avg_rally:Math.max(2,Math.round(4.6+(Number(ua.rally_tolerance||10)+Number(ua.patience||10)+Number(ua.footwork||10)+Number(ua.defensive_skill||10))*0.06+(Number(oa.rally_tolerance||10)+Number(oa.patience||10))*0.04-ag*.026+risk*.006+Math.random()*1.5))
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
      const nextCondition={
        fatigue:Math.min(100,Number(managed.data.fatigue||18)+12),
        fitness:Math.max(35,Number(managed.data.fitness||91)-5),
        form:Math.max(35,Math.min(100,Number(managed.data.form||72)+(won?3:-2))),
        morale:Math.max(35,Math.min(100,Number(managed.data.morale||78)+(won?2:-2)))
      };
      await db.from("players").update(nextCondition).eq("id",livePlayerId);
      if(isPrimaryLive)await db.from("career_state").update({...nextCondition,updated_at:new Date().toISOString()}).eq("id","demo");
      await db.from("match_history").insert({
        managed_player_id:livePlayerId,tournament_name:"Live Coaching",match_date:String(career.data.career_date),surface,
        round:"Exhibition",player_a:String(managed.data.name||"Joueur"),player_b:String(opp.data.name),
        winner:won?String(managed.data.name||"Joueur"):String(opp.data.name),
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

    const career=await db.from("career_state").select("*").eq("id","demo").maybeSingle();
    if(career.error||!career.data)return h({error:career.error?.message||"Données match incomplètes"},500);
    const livePlayerId=Number(session.data.managed_player_id||career.data.managed_player_id||0);
    const managed=await db.from("players").select("id,name,country,current_ability,form,fitness,fatigue,morale,player_attributes(*)").eq("id",livePlayerId).maybeSingle();
    if(managed.error||!managed.data)return h({error:managed.error?.message||"Joueur du match introuvable"},500);
    const isPrimaryLive=livePlayerId===Number(career.data.managed_player_id||0);

    const opp:any={...session.data.opponent,player_attributes:Array.isArray(session.data.opponent?.player_attributes)?session.data.opponent.player_attributes[0]:session.data.opponent?.player_attributes||{}};
    const ua:any=Array.isArray(managed.data.player_attributes)?managed.data.player_attributes[0]:managed.data.player_attributes||{};
    const oa:any=opp.player_attributes||{};
    const tactics=body?.tactics||session.data.tactics||{};
    const ag=n(tactics.aggression,58,1,100),risk=n(tactics.risk,52,1,100),net=n(tactics.net,28,1,100);
    const effort=n(tactics.effort,60,20,100);
    const ret=String(tactics.returnPos||"Neutre");
    const tempo=String(tactics.tempo||"Neutre");
    const targetWing=String(tactics.targetWing||"Mixte");
    const servePattern=String(tactics.servePattern||"Mixte");
    const spinPlan=String(tactics.spin||"Mixte");
    const surface=String(session.data.surface||"Dur");
    const key=surface==="Terre"?"clay_affinity":surface==="Gazon"?"grass_affinity":"hard_affinity";
    const meta:any=session.data.stats?._meta||{};
    const weather:any=meta.weather||{};
    const mood:any=meta.mood||{};
    const formMeta:any=meta.form||{};
    const userFormBonus=Number(formMeta.user_bonus||0),oppFormBonus=Number(formMeta.opponent_bonus||0);
    const courtSpeed=Math.max(.55,Math.min(1.45,Number(meta.court_speed||1)));
    const altitude=Math.max(0,Number(meta.altitude_m||0));
    const wind=Math.max(0,Number(weather.wind_kph||0));
    const humidity=Math.max(0,Number(weather.humidity_pct||50));
    const temperature=Number(weather.temperature_c||21);
    const moodUser=Number(mood.user||70),moodOpp=Number(mood.opponent||70);

    const pressure=(Math.max(Number(session.data.user_points||0),Number(session.data.opponent_points||0))>=3
      &&Math.abs(Number(session.data.user_points||0)-Number(session.data.opponent_points||0))<=1)?1:0;
    const serverIsUser=Boolean(session.data.serving_user);
    const serverId=serverIsUser?Number(managed.data.id):Number(opp.id);
    const returnerId=serverIsUser?Number(opp.id):Number(managed.data.id);
    const matchup=await db.rpc("tennis_abstract_matchup_model_v2",{
      p_server_id:serverId,p_returner_id:returnerId,p_surface:surface,p_pressure:pressure
    });
    const tm:any=matchup.error?{}:(matchup.data||{});
    const indoor=surface.toLowerCase().includes("intérieur")||surface.toLowerCase().includes("indoor");
    const clay=surface==="Terre"||surface.toLowerCase().includes("clay");
    const grass=surface==="Gazon"||surface.toLowerCase().includes("grass");
    const userMomentum=(Number(session.data.momentum||50)-50)*.0009;
    const sAttr:any=serverIsUser?ua:oa;
    const rAttr:any=serverIsUser?oa:ua;
    const sFormBonus=serverIsUser?userFormBonus:oppFormBonus;
    const rFormBonus=serverIsUser?oppFormBonus:userFormBonus;
    const avgAttr=(x:any,keys:string[],bonus=0)=>keys.reduce((sum,k)=>sum+Math.max(1,Math.min(20,Number(x?.[k]??10)+bonus)),0)/Math.max(1,keys.length);
    const surfaceKey=clay?"clay_affinity":grass?"grass_affinity":"hard_affinity";
    const groundEdge=(avgAttr(sAttr,["forehand_power","forehand_accuracy","forehand_consistency","backhand_power","backhand_accuracy","backhand_consistency","topspin","slice","shot_control","timing"],sFormBonus)
      -avgAttr(rAttr,["forehand_power","forehand_accuracy","forehand_consistency","backhand_power","backhand_accuracy","backhand_consistency","topspin","slice","shot_control","timing"],rFormBonus));
    const movementEdge=(avgAttr(sAttr,["movement","speed","acceleration","agility","balance","stamina","strength","natural_fitness","recovery","flexibility","footwork","athleticism","work_rate"],sFormBonus)
      -avgAttr(rAttr,["movement","speed","acceleration","agility","balance","stamina","strength","natural_fitness","recovery","flexibility","footwork","athleticism","work_rate"],rFormBonus));
    const mentalEdge=(avgAttr(sAttr,["concentration","tactics","decision_making","shot_selection","patience","killer_instinct","determination","fighting_spirit","big_points"],sFormBonus)
      -avgAttr(rAttr,["concentration","tactics","decision_making","shot_selection","patience","killer_instinct","determination","fighting_spirit","big_points"],rFormBonus));
    const netEdge=(avgAttr(sAttr,["volley","touch","half_volley","smash","net_positioning","transition_game","reaction"],sFormBonus)
      -avgAttr(rAttr,["passing_shot","lob","reaction","movement","defensive_skill","court_positioning","speed"],rFormBonus));
    const touchEdge=(avgAttr(sAttr,["drop_shot","touch","slice","lob","patience","tactics"],sFormBonus)
      -avgAttr(rAttr,["reaction","movement","speed","anticipation","court_positioning","agility"],rFormBonus));
    const surfaceEdge=Math.max(1,Math.min(20,Number(sAttr?.[surfaceKey]??10)+sFormBonus))-Math.max(1,Math.min(20,Number(rAttr?.[surfaceKey]??10)+rFormBonus));
    const formEdge=serverIsUser?userFormBonus-oppFormBonus:oppFormBonus-userFormBonus;
    const opponentBh=avgAttr(oa,["backhand","backhand_power","backhand_accuracy","backhand_consistency"],oppFormBonus);
    const opponentFh=avgAttr(oa,["forehand","forehand_power","forehand_accuracy","forehand_consistency"],oppFormBonus);
    const targetEdge=targetWing==="Revers"?Math.max(-4,Math.min(4,opponentFh-opponentBh))*.00115:
      targetWing==="Coup droit"?Math.max(-4,Math.min(4,opponentBh-opponentFh))*.00115:0;
    const spinEdge=spinPlan==="Lift"?(clay ? .006 : grass ? -.003 : .002):
      spinPlan==="Slice"?(grass ? .006 : indoor ? .003 : 0):
      spinPlan==="Plat"?(indoor ? .006 : clay ? -.004 : .003):0;
    const tempoEdge=tempo==="Rapide"?.0045:tempo==="Patient"?.002:0;
    const effortEdge=(effort-60)*.00032;
    const userTacticEdge=targetEdge+spinEdge+tempoEdge+effortEdge;
    const pointAttrEdge=Math.max(-.06,Math.min(.06,
      groundEdge*.00135+movementEdge*.00085+mentalEdge*(pressure?.00145:.00070)+
      netEdge*.00055+touchEdge*.00035+surfaceEdge*.0011+
      (serverIsUser?userTacticEdge:-userTacticEdge)
    ));

    let firstIn=Math.max(.42,Math.min(.82,Number(tm.first_serve_in_pct||62)/100
      -(serverIsUser?Math.max(-15,Math.min(35,risk-52))*.0010:0)
      -wind*.00075-Math.max(0,temperature-30)*.0012+formEdge*.0010));
    const firstServeIn=Math.random()<firstIn;
    const dfBase=Number(tm.double_fault_pct||4)/100;
    const doubleFault=!firstServeIn&&Math.random()<Math.max(.006,Math.min(.12,
      dfBase*(serverIsUser?(1+Math.max(-20,risk-50)*.005):1)
    ));

    let serverWinProb=Number(firstServeIn?tm.first_serve_point_win_prob:tm.second_serve_point_win_prob);
    if(!Number.isFinite(serverWinProb))serverWinProb=firstServeIn?.64:.51;
    serverWinProb+=pointAttrEdge*(firstServeIn?0.72:1.0);
    if(serverIsUser){
      serverWinProb+=(ag-58)*.0008+(risk-52)*.00035+Math.min(70,net)*.00007+userMomentum;
    }else{
      serverWinProb+=(ret==="Avancée"?-.012:ret==="Reculée"?.006:0)-userMomentum;
    }
    const serverMood=serverIsUser?moodUser:moodOpp,returnerMood=serverIsUser?moodOpp:moodUser;
    serverWinProb+=(serverMood-returnerMood)*.00055+(courtSpeed-1)*.045+(altitude/1000)*.018-wind*.00018+formEdge*.0018;
    serverWinProb=Math.max(.25,Math.min(.92,serverWinProb));

    const serverWon=!doubleFault&&Math.random()<serverWinProb;
    const userWon=serverIsUser?serverWon:!serverWon;

    const dirRoll=Math.random()*100;
    const wide=Number(tm.serve_wide_pct||38),bodyPct=Number(tm.serve_body_pct||14);
    let serveDirection=dirRoll<wide?"large":dirRoll<wide+bodyPct?"corps":"T";
    if(serverIsUser&&servePattern!=="Mixte"&&Math.random()<.68){
      serveDirection=servePattern==="Large"?"large":servePattern==="Corps"?"corps":"T";
    }
    const aceSurface=grass?1.18:indoor?1.13:clay?.78:1;
    const aceChance=Math.max(.002,Math.min(.28,Number(tm.ace_pct||6)/100*aceSurface
      *(serverIsUser?(1+Math.max(-20,risk-50)*.004):1)
      *(1+(courtSpeed-1)*.34+Math.min(.16,altitude/9000)-Math.min(.18,wind*.006))));
    const ace=firstServeIn&&serverWon&&Math.random()<aceChance;
    const unreturned=!ace&&!doubleFault&&serverWon&&Math.random()<Math.max(.02,Math.min(.45,
      Number(tm.unreturned_serve_pct||22)/100*(firstServeIn?1:.52)
    ));

    const rallyMean=Math.max(2.0,Math.min(10.5,
      Number(tm.avg_rally_shots||5)+(clay?.9:grass?-.7:indoor?-.35:0)
      -(courtSpeed-1)*2.1+Math.max(0,humidity-65)*.018
      +(tempo==="Patient"?.75:tempo==="Rapide"?-.60:0)
      +(spinPlan==="Lift"&&clay ? .40 : spinPlan==="Slice"&&grass ? -.25 : 0)
      +(serverIsUser?(55-risk)*.012:0)
      +(avgAttr(sAttr,["patience","rally_tolerance","stamina","defensive_skill","court_positioning"],sFormBonus)
        -avgAttr(rAttr,["patience","rally_tolerance","stamina","defensive_skill","court_positioning"],rFormBonus))*.035
    ));
    const rally=(ace||doubleFault||unreturned)?(doubleFault?0:1):Math.max(2,Math.min(18,
      2+Math.floor(-Math.log(Math.max(.001,1-Math.random()))*Math.max(1,rallyMean-2))
    ));
    const rallyBand=rally<=4?"0-4":rally<=8?"5-8":"9+";

    const winnerMetric=serverWon?Number(tm.server_winner_rate_pct||14):Number(tm.returner_winner_rate_pct||14);
    const forcedMetric=serverWon?Number(tm.server_forced_error_pct||12):Number(tm.returner_forced_error_pct||12);
    const loserUe=(serverWon?Number(tm.returner_ue_pct||15):Number(tm.server_ue_pct||15))
      +wind*.13+Math.max(0,temperature-29)*.30;
    let ending="rally_winner";
    if(doubleFault)ending="double_fault";
    else if(ace)ending="ace";
    else if(unreturned)ending="unreturned_serve";
    else{
      const total=Math.max(1,winnerMetric+forcedMetric+loserUe);
      const z=Math.random()*total;
      ending=z<winnerMetric?"winner":z<winnerMetric+forcedMetric?"forced_error":"unforced_error";
      if(!serverWon&&ending==="winner"&&rally<=3)ending="return_winner";
    }

    const returnDepthRoll=Math.random()*100;
    const returnDepthScore=Number(tm.return_depth_score||60);
    const returnDepth=returnDepthRoll<Math.max(15,returnDepthScore*.62)?"profond"
      :returnDepthRoll<Math.max(45,returnDepthScore*.62+28)?"moyen":"court";
    const serverNetChance=Math.max(0,Math.min(.55,
      Number(tm.server_net_approach_pct||10)/100+(serverIsUser?net*.0015:0)
      +(avgAttr(sAttr,["volley","touch","half_volley","net_positioning","transition_game"],sFormBonus)-10)*.0014
    ));
    const returnerNetChance=Math.max(0,Math.min(.40,Number(tm.returner_net_approach_pct||8)/100));
    const netRoll=Math.random();
    let netPlayerId:number|null=null;
    if(!ace&&!doubleFault&&!unreturned){
      if(netRoll<serverNetChance)netPlayerId=serverId;
      else if(netRoll<serverNetChance+(1-serverNetChance)*returnerNetChance)netPlayerId=returnerId;
    }
    const atNet=netPlayerId!==null;

    let up=Number(session.data.user_points||0),op=Number(session.data.opponent_points||0);
    if(userWon)up++;else op++;

    const lastPoint={
      winner:userWon?"user":"opponent",
      rally,rally_band:rallyBand,shot:ending,ending,
      serve_number:firstServeIn?1:2,first_serve_in:firstServeIn,
      double_fault:doubleFault,ace,unreturned_serve:unreturned,
      serve_direction:serveDirection,return_depth:returnDepth,at_net:atNet,net_player_id:netPlayerId,
      server:serverIsUser?"user":"opponent",
      server_win_probability:Math.round(serverWinProb*1000)/10,
      server_surface_elo:Number(tm.server_surface_elo||0),
      returner_surface_elo:Number(tm.returner_surface_elo||0),
      model:"CB-MATCH-ENGINE-v2 · point model",
      full_attribute_edge:Math.round(pointAttrEdge*10000)/10000,
      environment_effects:{
        court_speed:courtSpeed,wind_kph:wind,temperature_c:temperature,humidity_pct:humidity,
        altitude_m:altitude,user_mood:moodUser,opponent_mood:moodOpp
      },
      user_x:18+Math.floor(Math.random()*64),
      user_y:Math.max(56,Math.min(88,82-Math.round(net*.18)-Math.min(8,Math.floor(rally/2))+Math.floor(Math.random()*7-3))),
      opp_x:18+Math.floor(Math.random()*64),
      opp_y:Math.max(12,Math.min(44,18+Math.min(12,Math.floor(rally/2))+Math.floor(Math.random()*9-4))),
      ball_x:18+Math.floor(Math.random()*64),
      ball_y:userWon?20+Math.floor(Math.random()*28):52+Math.floor(Math.random()*28),
      zone:atNet?"Filet":ret==="Avancée"?"Prise tôt":ret==="Reculée"?"Retour reculé":"Neutre",
      at:new Date().toISOString()
    };

    const stats:any={
      user_winners:0,user_errors:0,user_aces:0,opp_winners:0,opp_errors:0,
      user_double_faults:0,opp_double_faults:0,
      user_first_serves:0,user_first_serves_in:0,opp_first_serves:0,opp_first_serves_in:0,
      user_unreturned_serves:0,opp_unreturned_serves:0,
      user_net_points:0,user_net_points_won:0,opp_net_points:0,opp_net_points_won:0,
      user_short_rallies_won:0,user_medium_rallies_won:0,user_long_rallies_won:0,
      opp_short_rallies_won:0,opp_medium_rallies_won:0,opp_long_rallies_won:0,
      ...(session.data.stats||{})
    };
    if(serverIsUser){
      stats.user_first_serves++;
      if(firstServeIn)stats.user_first_serves_in++;
      if(doubleFault)stats.user_double_faults++;
      if(ace)stats.user_aces++;
      if(unreturned)stats.user_unreturned_serves++;
    }else{
      stats.opp_first_serves++;
      if(firstServeIn)stats.opp_first_serves_in++;
      if(doubleFault)stats.opp_double_faults++;
      if(unreturned)stats.opp_unreturned_serves++;
    }
    if(atNet){
      const prefix=serverIsUser?"user":"opp";
      stats[prefix+"_net_points"]=(stats[prefix+"_net_points"]||0)+1;
      if(serverWon)stats[prefix+"_net_points_won"]=(stats[prefix+"_net_points_won"]||0)+1;
    }
    if(!ace&&!doubleFault&&!unreturned){
      if(ending==="winner"||ending==="return_winner"){
        if(userWon)stats.user_winners++;else stats.opp_winners++;
      }else{
        if(userWon)stats.opp_errors++;else stats.user_errors++;
      }
    }
    const bandKey=rallyBand==="0-4"?"short":rallyBand==="5-8"?"medium":"long";
    if(userWon)stats["user_"+bandKey+"_rallies_won"]=(stats["user_"+bandKey+"_rallies_won"]||0)+1;
    else stats["opp_"+bandKey+"_rallies_won"]=(stats["opp_"+bandKey+"_rallies_won"]||0)+1;

    let ug=Number(session.data.user_games||0),og=Number(session.data.opponent_games||0);
    let us=Number(session.data.user_sets||0),os=Number(session.data.opponent_sets||0);
    let setNo=Number(session.data.set_no||1),gameFinished=false,setFinished=false,setWinner="";
    const userName=String(managed.data.name||"Joueur");

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

    const finishedSetGames=setFinished?{user_games:ug,opponent_games:og}:null;
    const setsToWin=Math.max(2,Math.min(3,Number(meta.sets_to_win||2)));
    let status="active",completed=false;
    if(setFinished){
      if(us>=setsToWin||os>=setsToWin){status="finished";completed=true}
      else{setNo++;ug=0;og=0}
    }

    const log:any[]=Array.isArray(session.data.score_log)?session.data.score_log:[];
    if(gameFinished){
      log.push({
        set:Number(session.data.set_no||1),
        user_games:finishedSetGames?.user_games??ug,opponent_games:finishedSetGames?.opponent_games??og,
        winner_game:lastPoint.winner==="user"?userName:opp.name,set_finished:setFinished,set_winner:setWinner
      });
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

    const eventWrite=await db.from("live_match_point_events").upsert({
      session_id:id,
      point_no:Number(session.data.rally_no||0)+1,
      set_no:Number(session.data.set_no||1),
      server_id:serverId,
      returner_id:returnerId,
      winner_id:userWon?Number(managed.data.id):Number(opp.id),
      surface,
      pressure:Boolean(pressure),
      serve_number:firstServeIn?1:2,
      first_serve_in:firstServeIn,
      serve_direction:serveDirection,
      ace,
      double_fault:doubleFault,
      unreturned_serve:unreturned,
      return_depth:returnDepth,
      rally_length:rally,
      rally_band:rallyBand,
      ending,
      at_net:atNet,
      net_player_id:netPlayerId,
      server_surface_elo:Number(tm.server_surface_elo||0)||null,
      returner_surface_elo:Number(tm.returner_surface_elo||0)||null
    },{onConflict:"session_id,point_no"});

    // The final score is provisional until /api/live-match/commit.
    // This keeps ragequit / close-without-save a true rollback boundary.
    const observedAnalytics:any=null;

    return h({
      ok:true,session:saved.data,
      opponent:{id:opp.id,name:opp.name,country:opp.country,ranking:opp.ranking},
      point_winner:lastPoint.winner,game_finished:gameFinished,set_finished:setFinished,set_winner:setWinner,
      completed,win_probability:Math.round((serverIsUser?serverWinProb:1-serverWinProb)*100),
      last_point:lastPoint,
      point_analytics_error:eventWrite.error?eventWrite.error.message:null,
      observed_analytics:observedAnalytics
    });
  }


  if(path.endsWith("/api/live-match/game")&&req.method==="POST"){
    let body:any;try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const id=n(body?.session_id,0,1,99999999);
    const session=await db.from("live_match_sessions").select("*,opponent:players(id,name,country,ranking,current_ability,form,fitness,fatigue,style,player_attributes(*))").eq("id",id).maybeSingle();
    if(session.error||!session.data)return h({error:session.error?.message||"Match introuvable"},404);
    if(session.data.status!=="active")return h({ok:true,session:session.data,completed:true});

    const career=await db.from("career_state").select("*").eq("id","demo").maybeSingle();
    if(career.error||!career.data)return h({error:career.error?.message||"Données match incomplètes"},500);
    const livePlayerId=Number(session.data.managed_player_id||career.data.managed_player_id||0);
    const managed=await db.from("players").select("id,name,country,current_ability,form,fitness,fatigue,morale,player_attributes(*)").eq("id",livePlayerId).maybeSingle();
    if(managed.error||!managed.data)return h({error:managed.error?.message||"Joueur du match introuvable"},500);
    const isPrimaryLive=livePlayerId===Number(career.data.managed_player_id||0);

    const opp:any={...session.data.opponent,player_attributes:Array.isArray(session.data.opponent?.player_attributes)?session.data.opponent.player_attributes[0]:session.data.opponent?.player_attributes||{}};
    const ua:any=Array.isArray(managed.data.player_attributes)?managed.data.player_attributes[0]:managed.data.player_attributes||{};
    const tactics=body?.tactics||session.data.tactics||{};
    const ag=n(tactics.aggression,58,1,100),risk=n(tactics.risk,52,1,100),net=n(tactics.net,28,1,100);
    const effort=n(tactics.effort,60,20,100);
    const ret=String(tactics.returnPos||"Neutre");
    const tempo=String(tactics.tempo||"Neutre");
    const targetWing=String(tactics.targetWing||"Mixte");
    const spinPlan=String(tactics.spin||"Mixte");
    const surface=String(session.data.surface||"Dur");
    const key=surface==="Terre"?"clay_affinity":surface==="Gazon"?"grass_affinity":"hard_affinity";
    const meta:any=session.data.stats?._meta||{};
    const weather:any=meta.weather||{};
    const mood:any=meta.mood||{};
    const formMeta:any=meta.form||{};
    const userFormBonus=Number(formMeta.user_bonus||0),oppFormBonus=Number(formMeta.opponent_bonus||0);
    const courtSpeed=Math.max(.55,Math.min(1.45,Number(meta.court_speed||1)));
    const altitude=Math.max(0,Number(meta.altitude_m||0));
    const wind=Math.max(0,Number(weather.wind_kph||0));
    const temperature=Number(weather.temperature_c||21);
    const moodUser=Number(mood.user||70),moodOpp=Number(mood.opponent||70);

    const serverIsUser=Boolean(session.data.serving_user);
    const serverId=serverIsUser?Number(managed.data.id):Number(opp.id);
    const returnerId=serverIsUser?Number(opp.id):Number(managed.data.id);
    const matchup=await db.rpc("tennis_abstract_matchup_model_v2",{
      p_server_id:serverId,p_returner_id:returnerId,p_surface:surface,p_pressure:0
    });
    const tm:any=matchup.error?{}:(matchup.data||{});
    let serverPointP=Number(tm.expected_server_point_win_prob||.62);
    if(serverIsUser){
      serverPointP+=(ag-58)*.0007+(risk-52)*.00025+Math.min(70,net)*.00006+
        (Number(session.data.momentum||50)-50)*.0008;
    }else{
      serverPointP+=(ret==="Avancée"?-.010:ret==="Reculée"?.005:0)-
        (Number(session.data.momentum||50)-50)*.0008;
    }
    const serverMood=serverIsUser?moodUser:moodOpp,returnerMood=serverIsUser?moodOpp:moodUser;
    const oa:any=opp.player_attributes||{};
    const avg=(x:any,ks:string[])=>ks.reduce((z,k)=>z+Number(x?.[k]??10),0)/Math.max(1,ks.length);
    const targetEdge=targetWing==="Revers"?Math.max(-4,Math.min(4,avg(oa,["forehand","forehand_power","forehand_accuracy"])-avg(oa,["backhand","backhand_power","backhand_accuracy"])))*.0011:
      targetWing==="Coup droit"?Math.max(-4,Math.min(4,avg(oa,["backhand","backhand_power","backhand_accuracy"])-avg(oa,["forehand","forehand_power","forehand_accuracy"])))*.0011:0;
    const userTacticEdge=(effort-60)*.00030+(tempo==="Rapide"?.004:tempo==="Patient"?.002:0)+
      (spinPlan==="Lift"&&/Terre|clay/i.test(surface) ? .005 : spinPlan==="Slice"&&/Gazon|grass/i.test(surface) ? .005 : spinPlan==="Plat"&&/intérieur|indoor/i.test(surface) ? .005 : 0)+targetEdge;
    const serverFormBonus=serverIsUser?userFormBonus:oppFormBonus,returnerFormBonus=serverIsUser?oppFormBonus:userFormBonus;
    serverPointP+=(serverMood-returnerMood)*.00055+(courtSpeed-1)*.045+(altitude/1000)*.018-wind*.00018+(serverFormBonus-returnerFormBonus)*.0032;
    serverPointP=Math.max(.32,Math.min(.86,serverPointP));
    const q=1-serverPointP;
    const deuceWin=(serverPointP*serverPointP)/(serverPointP*serverPointP+q*q);
    const serverGameP=Math.max(.02,Math.min(.98,
      Math.pow(serverPointP,4)*(1+4*q+10*q*q)+
      20*Math.pow(serverPointP,3)*Math.pow(q,3)*deuceWin
    ));
    const prob=serverIsUser?serverGameP:1-serverGameP;
    const userWon=Math.random()<prob;

    let ug=Number(session.data.user_games||0),og=Number(session.data.opponent_games||0);
    let us=Number(session.data.user_sets||0),os=Number(session.data.opponent_sets||0);
    let setNo=Number(session.data.set_no||1);
    if(userWon)ug++;else og++;

    const stats:any={
      user_winners:0,user_errors:0,user_aces:0,opp_winners:0,opp_errors:0,
      user_double_faults:0,opp_double_faults:0,
      user_first_serves:0,user_first_serves_in:0,opp_first_serves:0,opp_first_serves_in:0,
      user_unreturned_serves:0,opp_unreturned_serves:0,
      ...(session.data.stats||{})
    };
    const gamePoints=6+Math.floor(Math.random()*5);
    const firstInPct=Math.max(.42,Math.min(.82,Number(tm.first_serve_in_pct||62)/100-wind*.00075-Math.max(0,temperature-30)*.0012));
    const acePct=Math.max(.002,Number(tm.ace_pct||6)/100*(1+(courtSpeed-1)*.34+Math.min(.16,altitude/9000)-Math.min(.18,wind*.006)));
    const dfPct=Number(tm.double_fault_pct||4)/100;
    const unretPct=Number(tm.unreturned_serve_pct||22)/100;
    const srvPrefix=serverIsUser?"user":"opp";
    stats[srvPrefix+"_first_serves"]=(stats[srvPrefix+"_first_serves"]||0)+gamePoints;
    stats[srvPrefix+"_first_serves_in"]=(stats[srvPrefix+"_first_serves_in"]||0)+Math.round(gamePoints*firstInPct);
    stats[srvPrefix+"_aces"]=(stats[srvPrefix+"_aces"]||0)+Math.max(0,Math.round(gamePoints*acePct*(.65+Math.random()*.7)));
    stats[srvPrefix+"_double_faults"]=(stats[srvPrefix+"_double_faults"]||0)+Math.max(0,Math.round(gamePoints*(1-firstInPct)*dfPct*(.65+Math.random()*.7)));
    stats[srvPrefix+"_unreturned_serves"]=(stats[srvPrefix+"_unreturned_serves"]||0)+Math.max(0,Math.round(gamePoints*unretPct*(.65+Math.random()*.7)));
    if(userWon){
      stats.user_winners+=(Math.max(1,Math.round(gamePoints*Number(serverIsUser?tm.server_winner_rate_pct:tm.returner_winner_rate_pct||14)/100)));
      stats.opp_errors+=Math.max(0,Math.round(gamePoints*Number(serverIsUser?tm.returner_ue_pct:tm.server_ue_pct||15)/100));
    }else{
      stats.opp_winners+=(Math.max(1,Math.round(gamePoints*Number(serverIsUser?tm.returner_winner_rate_pct:tm.server_winner_rate_pct||14)/100)));
      stats.user_errors+=Math.max(0,Math.round(gamePoints*Number(serverIsUser?tm.server_ue_pct:tm.returner_ue_pct||15)/100));
    }

    let setFinished=false,setWinner="";
    if(((ug>=6||og>=6)&&Math.abs(ug-og)>=2)||ug===7||og===7){
      setFinished=true;
      setWinner=ug>og?String(managed.data.name||"Joueur"):String(opp.name);
      if(ug>og)us++;else os++;
    }

    const log:any[]=Array.isArray(session.data.score_log)?session.data.score_log:[];
    log.push({set:setNo,user_games:ug,opponent_games:og,winner_game:userWon?String(managed.data.name||"Joueur"):opp.name,set_finished:setFinished,set_winner:setWinner});

    const setsToWin=Math.max(2,Math.min(3,Number(meta.sets_to_win||2)));
    let status="active",completed=false;
    if(setFinished){
      if(us>=setsToWin||os>=setsToWin){status="finished";completed=true}
      else{setNo++;ug=0;og=0}
    }

    const userName=String(managed.data.name||"Joueur");
    const momentumNew=Math.max(10,Math.min(90,Number(session.data.momentum||50)+(userWon?4:-4)+(setFinished?(setWinner===userName?8:-8):0)));
    const update:any={
      user_sets:us,opponent_sets:os,set_no:setNo,user_games:ug,opponent_games:og,
      serving_user:!session.data.serving_user,momentum:momentumNew,tactics,stats,score_log:log,
      status,updated_at:new Date().toISOString()
    };
    if(completed)update.completed_at=new Date().toISOString();

    const up=await db.from("live_match_sessions").update(update).eq("id",id).select("*").single();
    if(up.error)return h({error:up.error.message},500);

    // Do not mutate career/history/Elo here. The user can still discard this result.

    return h({
      ok:true,session:up.data,
      opponent:{id:opp.id,name:opp.name,country:opp.country,ranking:opp.ranking},
      game_winner:userWon?String(managed.data.name||"Joueur"):opp.name,set_finished:setFinished,set_winner:setWinner,
      completed,win_probability:Math.round(prob*100)
    });
  }


  if(path.endsWith("/api/live-match/commit")&&req.method==="POST"){
    let body:any;try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const id=n(body?.session_id,0,1,99999999);
    const session=await db.from("live_match_sessions")
      .select("*,opponent:players(id,name,country,ranking,current_ability,form,fitness,fatigue,morale)")
      .eq("id",id).maybeSingle();
    if(session.error||!session.data)return h({error:session.error?.message||"Match introuvable"},404);
    if(session.data.status==="committed")return h({ok:true,already_committed:true,session:session.data});
    if(!["finished","completed"].includes(String(session.data.status||""))){
      return h({error:"Le match doit être terminé avant validation.",status:session.data.status},409);
    }

    const career=await db.from("career_state").select("*").eq("id","demo").maybeSingle();
    if(career.error||!career.data)return h({error:career.error?.message||"Carrière introuvable"},500);
    const playerId=Number(session.data.managed_player_id||career.data.managed_player_id||0);
    const managed=await db.from("players")
      .select("id,name,country,form,fitness,fatigue,morale")
      .eq("id",playerId).maybeSingle();
    if(managed.error||!managed.data)return h({error:managed.error?.message||"Joueur introuvable"},404);

    const opp:any=Array.isArray(session.data.opponent)?session.data.opponent[0]:session.data.opponent;
    const stats:any=session.data.stats||{};
    const meta:any=stats._meta||{};
    const weather:any=meta.weather||{};
    const won=Number(session.data.user_sets||0)>Number(session.data.opponent_sets||0);
    const setRows=(Array.isArray(session.data.score_log)?session.data.score_log:[]).filter((x:any)=>x?.set_finished);
    const score=setRows.map((x:any)=>String(x.user_games)+"-"+String(x.opponent_games)).join(" ")||
      ("Sets "+String(session.data.user_sets||0)+"-"+String(session.data.opponent_sets||0));
    const heatLoad=Math.max(0,Number(weather.temperature_c||21)-27)*.20;
    const windLoad=Math.max(0,Number(weather.wind_kph||0)-14)*.06;
    const matchLoad=Math.min(8,Math.max(3,Math.ceil((Number(session.data.rally_no||0)+setRows.length*18)/55)));
    const effortLoad=Math.max(0,Number(session.data.tactics?.effort||60)-60)*.065;
    const fatigueAdd=Math.max(5,Math.min(18,Math.round(5+matchLoad+heatLoad+windLoad+effortLoad)));
    const nextCondition={
      fatigue:Math.min(100,Number(managed.data.fatigue||18)+fatigueAdd),
      fitness:Math.max(35,Number(managed.data.fitness||91)-Math.max(2,Math.ceil(fatigueAdd*.36))),
      form:Math.max(35,Math.min(100,Number(managed.data.form||72)+(won?2:-1))),
      morale:Math.max(30,Math.min(100,Number(managed.data.morale||72)+(won?3:-2)+Math.round((Number(meta.mood?.user||70)-70)*.04)))
    };

    const matchDate=String(meta.career_date||career.data.career_date||AGE_REFERENCE_DATE).slice(0,10);
    const tournamentName=String(meta.tournament?.name||"Live Match Center");
    const round=String(meta.round||"Match live");
    const history=await db.from("match_history").insert({
      managed_player_id:playerId,tournament_name:tournamentName,match_date:matchDate,
      surface:String(session.data.surface||"Dur"),round,
      player_a:String(managed.data.name||"Joueur"),player_b:String(opp?.name||"Adversaire"),
      winner:won?String(managed.data.name||"Joueur"):String(opp?.name||"Adversaire"),
      score,user_involved:true,
      match_data:{
        live:true,live_session_id:id,engine:"CB-MATCH-ENGINE-v2",
        stats,tactics:session.data.tactics||{},environment:meta
      }
    }).select("id").single();
    if(history.error)return h({error:history.error.message},500);

    const playerUpdate=await db.from("players").update(nextCondition).eq("id",playerId);
    if(playerUpdate.error)return h({error:playerUpdate.error.message},500);
    if(playerId===Number(career.data.managed_player_id||0)){
      const careerUpdate=await db.from("career_state").update({...nextCondition,updated_at:new Date().toISOString()}).eq("id","demo");
      if(careerUpdate.error)return h({error:careerUpdate.error.message},500);
    }

    const elo=await db.rpc("update_player_elo_after_match",{
      p_winner_id:won?playerId:Number(opp?.id||0),
      p_loser_id:won?Number(opp?.id||0):playerId,
      p_surface:String(session.data.surface||"Dur"),
      p_match_date:matchDate,p_doubles:false,p_weight:1
    });
    const learned=await db.rpc("finalize_live_match_analytics",{p_session_id:id,p_date:matchDate});
    const committed=await db.from("live_match_sessions")
      .update({status:"committed",updated_at:new Date().toISOString()})
      .eq("id",id).select("*").single();
    if(committed.error)return h({error:committed.error.message},500);

    return h({
      ok:true,committed:true,session:committed.data,history_id:history.data.id,
      result:{won,score,tournament_name:tournamentName,round},
      condition:nextCondition,fatigue_added:fatigueAdd,
      elo:elo.error?{error:elo.error.message}:elo.data,
      analytics:learned.error?{error:learned.error.message}:learned.data
    });
  }

  if(path.endsWith("/api/live-match/discard")&&req.method==="POST"){
    let body:any;try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const id=n(body?.session_id,0,1,99999999);
    const session=await db.from("live_match_sessions").select("id,status,managed_player_id").eq("id",id).maybeSingle();
    if(session.error||!session.data)return h({ok:true,discarded:false,missing:true});
    if(session.data.status==="committed")return h({error:"Un résultat déjà validé ne peut pas être annulé sans recharger une sauvegarde antérieure."},409);
    const p1=await db.from("live_match_point_events").delete().eq("session_id",id);
    if(p1.error)return h({error:p1.error.message},500);
    const p2=await db.from("live_match_events").delete().eq("session_id",id);
    if(p2.error)return h({error:p2.error.message},500);
    const del=await db.from("live_match_sessions").delete().eq("id",id);
    if(del.error)return h({error:del.error.message},500);
    return h({ok:true,discarded:true,session_id:id,managed_player_id:session.data.managed_player_id});
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
    const strength=(p:any)=>{
      const aa=p.player_attributes||{};
      const mind=(Number(aa.decision_making||10)+Number(aa.consistency||10)+Number(aa.big_points||10)+Number(aa.shot_selection||10))/4;
      return Number(p.current_ability||50)+Number(p.form||70)*.12+Number(p.fitness||85)*.06-Number(p.fatigue||20)*.08+Number(aa[key]||10)*.58+(mind-10)*.32;
    };
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

    const resolveActionManagedPlayer=async(requested:any)=>{
      const primaryId=Number(career.data.managed_player_id||0);
      const playerId=n(requested,primaryId,1,99999999);
      if(!playerId)return {error:"Joueur géré introuvable",status:409,primaryId,playerId:0,isPrimary:false,player:null};
      if(playerId!==primaryId){
        const roster=await db.from("academy_roster").select("id").eq("player_id",playerId).eq("status","active").maybeSingle();
        if(roster.error)return {error:roster.error.message,status:500,primaryId,playerId,isPrimary:false,player:null};
        if(!roster.data)return {error:"Ce joueur ne fait pas partie du groupe géré.",status:403,primaryId,playerId,isPrimary:false,player:null};
      }
      const player=await db.from("players").select("id,name,country,style,career_focus").eq("id",playerId).maybeSingle();
      if(player.error)return {error:player.error.message,status:500,primaryId,playerId,isPrimary:playerId===primaryId,player:null};
      if(!player.data)return {error:"Joueur géré introuvable",status:404,primaryId,playerId,isPrimary:playerId===primaryId,player:null};
      return {error:null,status:200,primaryId,playerId,isPrimary:playerId===primaryId,player:player.data};
    };

    if(action==="academy_setting"){
      const field=String(body?.field||"");
      const allowed=new Set(["academy_style","ncaa_pathway","pro_pathway","development_intensity","scholarship_budget","youth_capacity","recruitment_reach"]);
      if(!allowed.has(field))return h({error:"Réglage académie invalide"},400);
      let value:any=body?.value;
      if(["ncaa_pathway","pro_pathway"].includes(field))value=n(value,50,0,100);
      if(field==="development_intensity")value=n(value,2,1,5);
      if(field==="youth_capacity")value=n(value,8,4,30);
      if(field==="recruitment_reach")value=n(value,2,1,5);
      if(field==="scholarship_budget")value=Math.max(0,Math.min(100000,Number(value||0)));
      if(field==="academy_style")value=String(value||"Équilibré").slice(0,60);
      const up=await db.from("academies").update({[field]:value}).eq("id","demo").select("*").single();
      if(up.error)return h({error:up.error.message},500);
      return h({ok:true,academy:up.data});
    }

    if(action==="assign_head_of_youth"){
      const profileId=Number(id||0);
      const member=await db.from("staff")
        .select("id,name,role,profile_id,profile:staff_profiles(id,name,primary_role,youth_rating,development_rating,communication_rating,reputation)")
        .eq("profile_id",profileId).maybeSingle();
      if(member.error||!member.data)return h({error:member.error?.message||"Ce membre ne fait pas partie de ton staff."},404);
      const p:any=Array.isArray(member.data.profile)?member.data.profile[0]:member.data.profile||{};
      if(Number(p.youth_rating||0)<1)return h({error:"Ce membre du staff ne possède pas de profil formation jeunes."},409);
      const up=await db.from("academies").update({head_of_youth_profile_id:profileId}).eq("id","demo").select("*").single();
      if(up.error)return h({error:up.error.message},500);
      const today=String(career.data.career_date||AGE_REFERENCE_DATE);
      await db.from("inbox_items").insert({
        kind:"academy",title:"Direction de la formation mise à jour",
        body:String(p.name||member.data.name||"Le membre du staff")+" devient responsable du développement des jeunes.",
        action_route:"academy",is_read:false,game_date:today,priority:"normal",
        action_type:"open_route",action_label:"Voir l’académie",action_payload:{route:"academy"},decision_status:"info"
      });
      await db.from("career_event_log").insert({
        event_date:today,week:Number(career.data.week||1),system:"academy",event_type:"head_of_youth",
        entity_type:"staff_profile",entity_id:profileId,
        summary:"Nouveau responsable de la formation",
        payload:{staff_profile_id:profileId,name:p.name||member.data.name,youth_rating:Number(p.youth_rating||0)}
      });
      return h({ok:true,academy:up.data,head_of_youth:p});
    }

    if(action==="academy_pathway"){
      const decision=String(body?.decision||"").toLowerCase();
      if(!["pro","ncaa","release"].includes(decision))return h({error:"Décision académie invalide"},400);
      const y=await db.from("academy_youth").select("*").eq("id",id).maybeSingle();
      if(y.error||!y.data)return h({error:y.error?.message||"Prospect introuvable"},404);
      const today=String(career.data.career_date||AGE_REFERENCE_DATE);
      if(decision==="release"){
        const up=await db.from("academy_youth").update({status:"released",pathway_preference:"released",last_review_date:today}).eq("id",id);
        if(up.error)return h({error:up.error.message},500);
        await db.from("inbox_items").update({decision_status:"resolved",is_read:true})
          .eq("related_entity_type","academy_youth").eq("related_entity_id",id).eq("action_type","academy_pathway");
        await db.from("academy_intake_history").update({destination:"released"}).eq("youth_id",id);
        return h({ok:true,decision:"release"});
      }
      if(Number(y.data.age||0)<18)return h({error:"La décision NCAA / pro n'est disponible qu'à partir de 18 ans."},409);

      let playerId:number|null=null;
      const existing=await db.from("players").select("id").eq("slug","academy-youth-"+id).maybeSingle();
      if(existing.error)return h({error:existing.error.message},500);
      if(existing.data?.id)playerId=Number(existing.data.id);
      if(!playerId){
        const ca=Number(y.data.current_ability||45),pa=Number(y.data.potential||75);
        const ins=await db.from("players").insert({
          slug:"academy-youth-"+id,name:y.data.name,country:y.data.country||"FRA",is_real:false,
          ranking:decision==="pro"?2001+Number(id):null,source_ranking:null,points:0,
          doubles_ranking:decision==="pro"?2500+Number(id):null,
          itf_ranking:decision==="pro"?900+Number(id):null,
          junior_ranking:null,
          age:Number(y.data.age||18),birth_date:y.data.birth_date||null,
          height_cm:174+(Number(id)%18),weight_kg:66+(Number(id)%16),
          handedness:y.data.handedness||((Number(id)%5===0)?"Gaucher":"Droitier"),
          backhand:y.data.backhand||((Number(id)%7===0)?"1 main":"2 mains"),
          style:y.data.style||"À définir",current_ability:ca,potential:pa,
          form:68,fitness:92,morale:Number(y.data.morale||80),fatigue:10,
          scouting_confidence:100,injury_status:"Fit",
          data_source:"Court Boss Academy pathway",data_snapshot:today,ranking_current:false,
          ncaa_current:decision==="ncaa",ncaa_status:decision==="ncaa"?"Active":null
        }).select("id").single();
        if(ins.error)return h({error:ins.error.message},500);
        playerId=Number(ins.data.id);
        const base=Math.max(5,Math.min(17,Math.round(ca/6)));
        const attr=(salt:number)=>Math.max(4,Math.min(20,base+((Number(id)*salt)%5)-2));
        const attrs=await db.from("player_attributes").insert({
          player_id:playerId,serve_power:attr(3),serve_precision:attr(5),forehand:attr(7),backhand:attr(11),return_game:attr(13),
          volley:attr(17),touch:attr(19),movement:attr(23),speed:attr(29),stamina:attr(31),strength:attr(37),
          anticipation:attr(41),concentration:attr(43),composure:attr(47),fighting_spirit:attr(53),tactics:attr(59),
          doubles:attr(61),clay_affinity:attr(67),hard_affinity:attr(71),grass_affinity:attr(73)
        });
        if(attrs.error)return h({error:attrs.error.message},500);
      }

      let destination="";
      if(decision==="ncaa"){
        const teams=await db.from("college_teams").select("id,name,ita_rank,preseason_rank").order("ita_rank",{ascending:true,nullsFirst:false}).limit(30);
        if(teams.error||!(teams.data??[]).length)return h({error:teams.error?.message||"Aucune université NCAA disponible"},500);
        const pool=teams.data??[];
        const qualityBand=Math.max(0,Math.min(pool.length-1,Math.floor((95-Number(y.data.potential||75))/4)));
        const choice=pool[Math.min(pool.length-1,qualityBand+(Number(id)%Math.min(5,Math.max(1,pool.length-qualityBand))))]||pool[0];
        destination=String(choice.name);
        const seasonStart=Number(today.slice(5,7))>=8?Number(today.slice(0,4)):Number(today.slice(0,4))-1;
        const season=String(seasonStart)+"-"+String((seasonStart+1)%100).padStart(2,"0");
        const projected=126+Math.max(0,Math.min(350,Math.round((90-Number(y.data.current_ability||45))*4+(Number(id)%29))));
        const [pp,reg,uy]=await Promise.all([
          db.from("players").update({
            ncaa_current:true,ncaa_school:destination,ncaa_status:"Active",ncaa_verified:false,
            ncaa_rank:null,ncaa_class_year:"Freshman",ranking_current:false,ranking:null,itf_ranking:null
          }).eq("id",playerId),
          db.from("ncaa_player_registry").upsert({
            player_id:playerId,ita_rank:null,ita_rank_official:null,projected_rank:projected,
            school:destination,division:"NCAA D1",season,status:"Active",snapshot_date:today,
            source_label:"Court Boss Academy pathway · simulated depth",rank_source_kind:"simulated_depth",class_year:"Freshman"
          },{onConflict:"player_id,season"}),
          db.from("academy_youth").update({
            status:"ncaa",pathway_preference:"ncaa",last_review_date:today
          }).eq("id",id)
        ]);
        const er=pp.error||reg.error||uy.error;if(er)return h({error:er.message},500);
        await db.from("academy_intake_history").update({destination:"NCAA · "+destination}).eq("youth_id",id);
        await db.from("inbox_items").insert({
          kind:"academy",title:y.data.name+" rejoint la NCAA",
          body:y.data.name+" s'engage avec "+destination+". Son classement affiché restera une projection Court Boss tant qu'il n'existe pas de rang ITA officiel.",
          action_route:"university",is_read:false,game_date:today,priority:"normal",
          action_type:"open_route",action_label:"Voir la NCAA",action_payload:{route:"university"},
          related_entity_type:"player",related_entity_id:playerId,decision_status:"info"
        });
      }else{
        const existingRoster=await db.from("academy_roster").select("id").eq("source_youth_id",id).maybeSingle();
        if(existingRoster.error)return h({error:existingRoster.error.message},500);
        const cost=Number(y.data.scholarship_cost||0);
        if(!existingRoster.data&&budget<cost)return h({error:"Budget insuffisant pour le passage pro."},409);
        if(!existingRoster.data){
          budget-=cost;
          const endDate=new Date(today+"T12:00:00Z");endDate.setUTCFullYear(endDate.getUTCFullYear()+2);
          const weeklyCost=Math.max(100,Math.round(Number(y.data.current_ability||45)*5));
          const ro=await db.from("academy_roster").insert({
            player_id:playerId,source_youth_id:id,contract_start:today,contract_end:endDate.toISOString().slice(0,10),
            weekly_cost:weeklyCost,squad_role:"Passage pro",development_focus:"Équilibré",status:"active"
          });
          if(ro.error)return h({error:ro.error.message},500);
          await db.from("contracts").insert({
            subject_type:"player",subject_name:y.data.name,role:"Joueur pro académie",weekly_salary:weeklyCost,
            start_date:today,end_date:endDate.toISOString().slice(0,10),bonuses:{top500_bonus:1000,title_bonus:750},status:"active"
          });
          await db.from("career_state").update({budget,updated_at:new Date().toISOString()}).eq("id","demo");
        }
        const [pp,uy]=await Promise.all([
          db.from("players").update({
            ncaa_current:false,ncaa_school:null,ncaa_status:null,ranking_current:false,
            ranking:2001+Number(id),itf_ranking:900+Number(id)
          }).eq("id",playerId),
          db.from("academy_youth").update({
            status:"signed",pathway_preference:"pro",signed_on:today,last_review_date:today
          }).eq("id",id)
        ]);
        const er=pp.error||uy.error;if(er)return h({error:er.message},500);
        destination="Circuit pro";
        await db.from("academy_intake_history").update({signed:true,destination:"Circuit pro"}).eq("youth_id",id);
        await db.from("inbox_items").insert({
          kind:"academy",title:y.data.name+" passe professionnel",
          body:y.data.name+" signe son premier contrat professionnel avec l'académie.",
          action_route:"academy",is_read:false,game_date:today,priority:"normal",
          action_type:"open_route",action_label:"Voir l'académie",action_payload:{route:"academy"},
          related_entity_type:"player",related_entity_id:playerId,decision_status:"info"
        });
      }

      await db.from("inbox_items").update({decision_status:"resolved",is_read:true})
        .eq("related_entity_type","academy_youth").eq("related_entity_id",id).eq("action_type","academy_pathway");

      await db.from("career_event_log").insert({
        event_date:today,week:Number(career.data.week||0),system:"academy",event_type:"pathway_decision",
        entity_type:"academy_youth",entity_id:id,summary:y.data.name+" → "+destination,
        payload:{decision,player_id:playerId,destination}
      });
      return h({ok:true,decision,player_id:playerId,destination,budget});
    }

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
      await recordFinanceTransactions([{
        transaction_key:"academy-youth:"+id+":signing",game_date:start,week:Number(career.data.week||1),
        category:"academy_signing",amount:-cost,source_type:"academy_youth",source_id:id,
        description:"Bourse / signature jeune · "+String(y.data.name),balance_after:budget,
        metadata:{player_id:playerId,weekly_cost:weeklyCost}
      }]);
      return h({ok:true,budget,status:"signed",player_id:playerId,roster:roster.data});
    }

    if(action==="enroll_staff_training"){
      const member=await db.from("staff").select("*").eq("id",id).maybeSingle();
      if(member.error||!member.data)return h({error:member.error?.message||"Membre du staff introuvable"},404);
      if(!member.data.profile_id)return h({error:"Ce membre du staff n'a pas encore de profil de formation."},409);

      const centerId=n(body?.center_id,0,1,99999999);
      const center=await db.from("staff_training_centers").select("*").eq("id",centerId).eq("active",true).maybeSingle();
      if(center.error||!center.data)return h({error:center.error?.message||"Centre de formation introuvable"},404);

      const activeCourse=await db.from("staff_training_enrollments")
        .select("id,center_id,focus,progress,expected_end")
        .eq("staff_profile_id",member.data.profile_id).eq("status","active").maybeSingle();
      if(activeCourse.error)return h({error:activeCourse.error.message},500);
      if(activeCourse.data)return h({error:"Ce membre du staff suit déjà une formation.",course:activeCourse.data},409);

      const occupancy=await db.from("staff_training_enrollments")
        .select("id",{count:"exact",head:true})
        .eq("center_id",centerId).eq("status","active");
      if(occupancy.error)return h({error:occupancy.error.message},500);
      if(Number(occupancy.count||0)>=Number(center.data.capacity||50))return h({error:"Ce centre est complet pour le moment."},409);

      const cost=Number(center.data.course_cost||1500+Number(center.data.reputation||10)*220);
      if(budget<cost)return h({error:"Budget insuffisant pour cette formation."},409);

      const start=String(career.data.career_date||AGE_REFERENCE_DATE);
      const endDate=new Date(start+"T12:00:00Z");
      endDate.setUTCDate(endDate.getUTCDate()+Number(center.data.course_weeks||10)*7);
      const focus=String(body?.focus||center.data.specialty||"Technique");
      budget-=cost;

      const [ins,car]=await Promise.all([
        db.from("staff_training_enrollments").insert({
          center_id:centerId,staff_profile_id:member.data.profile_id,
          start_date:start,expected_end:endDate.toISOString().slice(0,10),
          focus,progress:0,status:"active",cost,user_managed:true
        }),
        db.from("career_state").update({budget,updated_at:new Date().toISOString()}).eq("id","demo")
      ]);
      const er=ins.error||car.error;
      if(er)return h({error:er.message},500);

      await db.from("staff_career_events").insert({
        staff_profile_id:member.data.profile_id,event_date:start,event_type:"training_started",
        role:member.data.role,description:"Début d'une formation "+focus+" à "+center.data.name+"."
      });
      await db.from("inbox_items").insert({
        kind:"staff",title:"Formation staff",
        body:(member.data.name||member.data.role)+" débute une formation "+focus+" à "+center.data.name+".",
        action_route:"staff",is_read:false
      });
      await recordFinanceTransactions([{
        transaction_key:"staff-training:"+member.data.id+":"+centerId+":"+start,game_date:start,week:Number(career.data.week||1),
        category:"staff_training",amount:-cost,source_type:"staff_profile",source_id:Number(member.data.profile_id||0)||null,
        description:"Formation staff · "+String(member.data.name||member.data.role)+" · "+String(center.data.name),balance_after:budget,
        metadata:{focus,expected_end:endDate.toISOString().slice(0,10)}
      }]);

      return h({ok:true,budget,cost,focus,expected_end:endDate.toISOString().slice(0,10),center:center.data.name});
    }

    if(action==="approach_staff"){
      const target=await resolveActionManagedPlayer(body?.player_id);
      if(target.error)return h({error:target.error},target.status);
      const profile=await db.from("staff_profiles").select("*").eq("id",id).maybeSingle();
      if(profile.error||!profile.data)return h({error:profile.error?.message||"Profil staff introuvable"},404);
      const p:any=profile.data;
      if(!p.active)return h({error:"Ce membre du staff n'est plus actif."},409);
      if(String(p.market_status||"")!=="available")return h({error:"Ce membre du staff est actuellement sous contrat ou indisponible."},409);
      const managedId=target.playerId;
      const fit=managedId?await db.rpc("staff_fit_score",{p_player_id:managedId,p_staff_id:id,p_role:p.primary_role}):{data:60,error:null};
      if(fit.error)return h({error:fit.error.message},500);
      const fitValue=Array.isArray(fit.data)?Number(fit.data[0]||60):Number(fit.data||60);
      const already=await db.from("staff_candidates").select("id,status").eq("profile_id",id).maybeSingle();
      if(already.error)return h({error:already.error.message},500);
      if(already.data){
        const existingUp=await db.from("staff_candidates").update({
          status:"available",interview_status:"not_started",managed_fit:fitValue
        }).eq("id",already.data.id);
        if(existingUp.error)return h({error:existingUp.error.message},500);
        return h({ok:true,candidate_id:already.data.id,existing:true,managed_fit:fitValue,player_id:managedId});
      }
      const role=String(p.primary_role||"Staff"),low=role.toLowerCase();
      const skill=low.includes("double")?Number(p.doubles_coaching_rating||p.coach_rating||10):low.includes("kin")||low.includes("ost")||low.includes("méd")||low.includes("med")?Number(p.medical_rating||10):low.includes("phys")?Number(p.fitness_rating||10):low.includes("recrut")||low.includes("scout")?Number(p.scouting_rating||10):low.includes("anal")?Math.max(Number(p.tactical_rating||10),Number(p.scouting_rating||10)):low.includes("mental")?Number(p.mental_rating||10):low.includes("agent")?Number(p.negotiation_rating||10):Number(p.coach_rating||10);
      const weekly=Math.max(100,Math.round(Number(p.asking_weekly_cost||500)));
      const signing=Math.round(weekly*(1.35+Number(p.reputation||10)*.055));
      const offers=await db.from("staff_competing_offers").select("id",{count:"exact",head:true}).eq("staff_profile_id",id).eq("status","pending");
      const ins=await db.from("staff_candidates").insert({
        name:p.name,role,skill,weekly_cost:weekly,signing_cost:signing,
        specialty:p.specialty||"Performance",status:"available",profile_id:id,
        managed_fit:fitValue,interview_status:"not_started",competing_offers:Number(offers.count||0)
      }).select("id").single();
      if(ins.error)return h({error:ins.error.message},500);
      return h({ok:true,candidate_id:ins.data.id,existing:false,managed_fit:fitValue,player_id:managedId});
    }

    if(action==="interview_staff"){
      const target=await resolveActionManagedPlayer(body?.player_id);
      if(target.error)return h({error:target.error},target.status);
      const cand=await db.from("staff_candidates").select("*,profile:staff_profiles(*)").eq("id",id).maybeSingle();
      if(cand.error||!cand.data)return h({error:cand.error?.message||"Candidate not found"},404);
      if(cand.data.status!=="available")return h({error:"Ce candidat n'est plus disponible."},409);

      const p:any=Array.isArray(cand.data.profile)?cand.data.profile[0]:cand.data.profile||{};
      const managedId=target.playerId;
      const fitRpc=managedId&&p.id?await db.rpc("staff_fit_score",{p_player_id:managedId,p_staff_id:p.id,p_role:p.primary_role}):{data:60,error:null};
      if(fitRpc.error)return h({error:fitRpc.error.message},500);
      const fit=Array.isArray(fitRpc.data)?Number(fitRpc.data[0]||60):Number(fitRpc.data||60);
      const competing=Number(cand.data.competing_offers||0);
      const managed={data:target.player,error:null};
      const priorBond=managedId&&p.id
        ?await db.from("staff_player_bonds").select("bond_type,affinity,trust,respect").eq("staff_profile_id",p.id).eq("player_id",managedId).eq("active",true).maybeSingle()
        :{data:null,error:null};
      const ownStaff=await db.from("staff").select("profile_id").not("profile_id","is",null);
      const ownIds=(ownStaff.data??[]).map((x:any)=>Number(x.profile_id)).filter(Boolean);
      let recommendationBoost=0;
      if(ownIds.length&&p.id){
        const recs=await db.from("staff_recommendations")
          .select("from_staff_id,to_staff_id,strength")
          .eq("active",true)
          .or(`and(from_staff_id.in.(${ownIds.join(",")}),to_staff_id.eq.${p.id}),and(to_staff_id.in.(${ownIds.join(",")}),from_staff_id.eq.${p.id})`)
          .order("strength",{ascending:false}).limit(3);
        if(!recs.error&&recs.data?.length)recommendationBoost=Math.min(8,Math.round(Math.max(...recs.data.map((x:any)=>Number(x.strength||0)))/12));
      }
      const pref=await db.from("staff_preferences").select("*").eq("staff_profile_id",p.id).maybeSingle();
      const countryFit=pref.data?.preferred_player_country&&managed.data?.country===pref.data.preferred_player_country?5:0;
      const styleFit=pref.data?.preferred_style&&managed.data?.style===pref.data.preferred_style?4:0;
      const bondBoost=priorBond.data
        ?Math.max(-8,Math.min(14,Math.round(
          (Number(priorBond.data.affinity||50)-50)*.12+
          (Number(priorBond.data.trust||50)-50)*.10+
          (Number(priorBond.data.respect||50)-50)*.06
        )))
        :0;
      const interest=Math.max(20,Math.min(99,Math.round(
        fit*.60+Number(p.reputation||10)*1.15+Number(p.loyalty||10)*.35-Number(p.ambition||10)*.25-competing*2
        +recommendationBoost+countryFit+styleFit+bondBoost
      )));
      const agencyLink=p.id?await db.from("staff_agency_members").select("agency:staff_agencies(commission_pct,reputation,network_strength)").eq("staff_profile_id",p.id).eq("active",true).maybeSingle():{data:null,error:null};
      const agency:any=Array.isArray(agencyLink.data?.agency)?agencyLink.data.agency[0]:agencyLink.data?.agency||{};
      const agencyCommission=Number(agency.commission_pct||0);
      const requestedWeekly=Math.max(
        Number(cand.data.weekly_cost||0),
        Math.round(Number(p.asking_weekly_cost||cand.data.weekly_cost||0)*(1+Math.max(0,Number(p.ambition||10)-10)*.012+competing*.035))
      );
      const requestedSigning=Math.max(
        Number(cand.data.signing_cost||0),
        Math.round(requestedWeekly*(1.2+Number(p.reputation||10)*.06+competing*.12)*(1+agencyCommission/100))
      );
      const years=Number(p.reputation||10)>=17?3:Number(p.ambition||10)>=16?2:1;
      const demands={
        lead_role:Boolean(pref.data?.wants_lead_role),
        shared_role:Boolean(pref.data?.willing_shared_role),
        preferred_circuits:pref.data?.preferred_circuits||[],
        travel_tolerance:Number(pref.data?.travel_tolerance||10),
        performance_bonus:Number(p.reputation||10)>=15,
        release_clause:Number(p.ambition||10)>=16,
        minimum_fit:Math.max(55,fit-5),
        target_player_id:managedId
      };
      const status=interest>=42?"completed":"rejected";
      const start=String(career.data.career_date||AGE_REFERENCE_DATE);

      await db.from("staff_interviews").upsert({
        staff_profile_id:p.id,candidate_id:id,interview_date:start,status,interest,
        requested_weekly:requestedWeekly,requested_signing:requestedSigning,
        desired_years:years,demands,
        notes:status==="completed"?"Entretien positif. Conditions communiquées.":"Le candidat n'est pas suffisamment intéressé."
      },{onConflict:"staff_profile_id,interview_date"});

      const up=await db.from("staff_candidates").update({
        managed_fit:fit,interview_status:status,interest,
        requested_weekly:requestedWeekly,requested_signing:requestedSigning,
        desired_years:years,demands,
        weekly_cost:requestedWeekly,signing_cost:requestedSigning
      }).eq("id",id);
      if(up.error)return h({error:up.error.message},500);

      return h({ok:true,status,interest,requested_weekly:requestedWeekly,requested_signing:requestedSigning,desired_years:years,demands,competing_offers:competing,recommendation_boost:recommendationBoost,bond_boost:bondBoost,agency_commission:agencyCommission,player_id:managedId,managed_fit:fit});
    }

    if(action==="counter_staff_offer"){
      const cand=await db.from("staff_candidates").select("*,profile:staff_profiles(*)").eq("id",id).maybeSingle();
      if(cand.error||!cand.data)return h({error:cand.error?.message||"Candidate not found"},404);
      if(cand.data.status!=="available")return h({error:"Ce candidat n'est plus disponible."},409);
      if(cand.data.interview_status!=="completed")return h({error:"Passe d'abord un entretien avec ce candidat."},409);

      const p:any=Array.isArray(cand.data.profile)?cand.data.profile[0]:cand.data.profile||{};
      const requestedWeekly=Math.max(1,Number(cand.data.requested_weekly||cand.data.weekly_cost||1));
      const requestedSigning=Math.max(0,Number(cand.data.requested_signing||cand.data.signing_cost||0));
      const wantedYears=Math.max(1,Number(cand.data.desired_years||2));
      const offeredWeekly=Math.max(0,Math.round(Number(body?.weekly||requestedWeekly)));
      const offeredSigning=Math.max(0,Math.round(Number(body?.signing||requestedSigning)));
      const offeredYears=Math.max(1,Math.min(5,Math.round(Number(body?.years||wantedYears))));
      const interest=Number(cand.data.interest||50);
      const fit=Number(cand.data.managed_fit||60);
      const competing=Number(cand.data.competing_offers||0);

      const weeklyScore=Math.min(1.15,offeredWeekly/requestedWeekly)*45;
      const signingScore=requestedSigning>0?Math.min(1.20,offeredSigning/requestedSigning)*18:18;
      const durationScore=Math.max(0,10-Math.abs(offeredYears-wantedYears)*4);
      const projectScore=interest*.13+fit*.09;
      const threshold=76
        +Math.max(0,Number(p.ambition||10)-10)*.55
        +Math.max(0,Number(p.reputation||10)-12)*.45
        +competing*1.5
        -Math.max(0,Number(p.loyalty||10)-10)*.20;
      const score=weeklyScore+signingScore+durationScore+projectScore;

      const oldDemands:any=cand.data.demands||{};
      if(score>=threshold){
        const newDemands={...oldDemands,negotiation_status:"agreed",last_offer_score:Math.round(score),last_offer_date:String(career.data.career_date||AGE_REFERENCE_DATE)};
        const up=await db.from("staff_candidates").update({
          requested_weekly:offeredWeekly,
          requested_signing:offeredSigning,
          desired_years:offeredYears,
          demands:newDemands,
          interest:Math.min(99,interest+4)
        }).eq("id",id);
        if(up.error)return h({error:up.error.message},500);
        return h({ok:true,status:"accepted",score:Math.round(score),threshold:Math.round(threshold),weekly:offeredWeekly,signing:offeredSigning,years:offeredYears});
      }

      const gap=Math.max(0,threshold-score);
      const counterWeekly=Math.round(Math.max(offeredWeekly,requestedWeekly*(gap<8?.97:gap<16?.99:1)));
      const counterSigning=Math.round(Math.max(offeredSigning,requestedSigning*(gap<8?.94:gap<16?.98:1)));
      const newDemands={...oldDemands,negotiation_status:"counter",last_offer_score:Math.round(score),last_offer_date:String(career.data.career_date||AGE_REFERENCE_DATE)};
      const up=await db.from("staff_candidates").update({
        requested_weekly:counterWeekly,
        requested_signing:counterSigning,
        desired_years:wantedYears,
        demands:newDemands,
        interest:Math.max(20,interest-(gap>=18?5:2))
      }).eq("id",id);
      if(up.error)return h({error:up.error.message},500);
      return h({ok:true,status:"counter",score:Math.round(score),threshold:Math.round(threshold),weekly:counterWeekly,signing:counterSigning,years:wantedYears});
    }

    if(action==="hire_staff"){
      const target=await resolveActionManagedPlayer(body?.player_id);
      if(target.error)return h({error:target.error},target.status);
      const cand=await db.from("staff_candidates").select("*").eq("id",id).maybeSingle();
      if(cand.error||!cand.data)return h({error:cand.error?.message||"Candidate not found"},404);
      if(cand.data.status==="hired")return h({ok:true,already:true,budget});
      if(cand.data.status!=="available")return h({error:"Ce membre du staff n'est pas disponible actuellement."},409);
      if(cand.data.profile_id&&cand.data.interview_status==="not_started")return h({error:"Un entretien est obligatoire avant de faire signer ce candidat."},409);
      if(cand.data.interview_status==="rejected")return h({error:"Le candidat a refusé les conditions après l'entretien."},409);
      const interviewTarget=Number((cand.data.demands as any)?.target_player_id||0);
      if(interviewTarget&&interviewTarget!==target.playerId){
        return h({error:"Cet entretien concernait un autre joueur géré. Relance un entretien pour le joueur actif."},409);
      }
      const cost=Number(cand.data.requested_signing||cand.data.signing_cost||0);
      if(budget<cost)return h({error:"Budget insuffisant"},409);
      budget-=cost;
      const start=String(career.data.career_date||AGE_REFERENCE_DATE);
      const endDate=new Date(start+"T12:00:00Z");
      endDate.setUTCFullYear(endDate.getUTCFullYear()+Math.max(1,Number(cand.data.desired_years||2)));
      const managedId=target.playerId;
      const weekly=Number(cand.data.requested_weekly||cand.data.weekly_cost||0);
      const demands:any=cand.data.demands||{};
      const wantsLead=Boolean(demands.lead_role)&&/coach/i.test(String(cand.data.role||""));
      const effectiveRole=wantsLead?"Coach principal":String(cand.data.role||"Staff");
      if(wantsLead&&managedId){
        const oldLead=await db.from("player_staff_assignments")
          .select("id,staff_profile_id").eq("player_id",managedId).eq("active",true).ilike("role","%principal%").maybeSingle();
        if(oldLead.data){
          await db.from("player_staff_assignments").update({role:"Coach adjoint",notes:"Repositionné après arrivée d'un nouveau coach principal."}).eq("id",oldLead.data.id);
          if(oldLead.data.staff_profile_id)await db.from("staff").update({role:"Coach adjoint"}).eq("profile_id",oldLead.data.staff_profile_id);
        }
      }
      const fit=cand.data.profile_id&&managedId
        ?await db.rpc("staff_fit_score",{p_player_id:managedId,p_staff_id:cand.data.profile_id,p_role:effectiveRole})
        :{data:60,error:null};
      const fitValue=Array.isArray(fit.data)?Number(fit.data[0]||60):Number(fit.data||60);
      const [ins,up,car,contract,profileUp,assignment,offers]=await Promise.all([
        db.from("staff").insert({name:cand.data.name,role:effectiveRole,skill:cand.data.skill,weekly_cost:weekly,profile_id:cand.data.profile_id||null}),
        db.from("staff_candidates").update({status:"hired"}).eq("id",id),
        db.from("career_state").update({budget,updated_at:new Date().toISOString()}).eq("id","demo"),
        db.from("contracts").insert({
          subject_type:"staff",subject_name:cand.data.name,role:effectiveRole,
          weekly_salary:weekly,start_date:start,
          end_date:endDate.toISOString().slice(0,10),
          bonuses:{loyalty_bonus:Math.round(weekly*2),demands:cand.data.demands||{}},
          status:"active"
        }),
        cand.data.profile_id
          ?db.from("staff_profiles").update({market_status:"user_staff",available_from:null}).eq("id",cand.data.profile_id)
          :Promise.resolve({error:null}),
        cand.data.profile_id&&managedId
          ?db.from("player_staff_assignments").insert({
            player_id:managedId,staff_profile_id:cand.data.profile_id,role:effectiveRole,
            start_date:start,active:true,verified:false,affinity:72,trust:70,
            source_label:"Court Boss · staff joueur géré",snapshot_date:start,
            notes:"Recruté par le joueur géré après entretien.",weekly_salary:weekly,
            contract_end:endDate.toISOString().slice(0,10),assignment_generation:1,last_review_date:start,
            role_fit:fitValue,satisfaction:Math.max(55,Math.min(95,Math.round(62+fitValue*.2))),
            team_chemistry:Math.max(55,Math.min(95,Math.round(61+fitValue*.22)))
          })
          :Promise.resolve({error:null}),
        cand.data.profile_id
          ?db.from("staff_competing_offers").update({status:"lost_to_user"}).eq("staff_profile_id",cand.data.profile_id).eq("status","pending")
          :Promise.resolve({error:null})
      ]);
      const err=ins.error||up.error||car.error||contract.error||profileUp.error||assignment.error||offers.error;if(err)return h({error:err.message},500);
      const agentSync=/agent/i.test(effectiveRole)
        ?await db.rpc("sync_managed_agent_representation",{p_date:start})
        :{data:null,error:null};
      await db.from("inbox_items").insert({kind:"staff",title:"Recrutement staff",body:cand.data.name+" rejoint ton équipe comme "+effectiveRole+" jusqu'au "+endDate.toISOString().slice(0,10)+".",action_route:"staff",is_read:false});
      if(/agent/i.test(effectiveRole)&&!agentSync.error){
        await db.from("inbox_items").insert({kind:"commercial",title:"Nouvelle représentation",body:cand.data.name+" devient ton agent principal. Ton agence et sa commission sont désormais liées à ce profil.",action_route:"staff",is_read:false});
      }
      return h({ok:true,budget,status:"hired",player_id:managedId,contract_end:endDate.toISOString().slice(0,10),agent_representation:agentSync.error?{error:agentSync.error.message}:agentSync.data});
    }

    if(action==="fire_staff"){
      const member=await db.from("staff").select("*").eq("id",id).maybeSingle();
      if(member.error||!member.data)return h({error:member.error?.message||"Membre du staff introuvable"},404);
      const severance=Math.max(0,Math.round(Number(member.data.weekly_cost||0)*4));
      if(budget<severance)return h({error:"Budget insuffisant pour l'indemnité de départ"},409);
      budget-=severance;

      const managedId=Number(career.data.managed_player_id||0);
      const fireDate=String(career.data.career_date||AGE_REFERENCE_DATE);
      const [del,car,contracts,profileUp,candUp,assignmentUp]=await Promise.all([
        db.from("staff").delete().eq("id",id),
        db.from("career_state").update({budget,updated_at:new Date().toISOString()}).eq("id","demo"),
        db.from("contracts").update({status:"terminated"}).eq("subject_type","staff").eq("subject_name",member.data.name||member.data.role).eq("status","active"),
        member.data.profile_id
          ?db.from("staff_profiles").update({market_status:"available",available_from:fireDate}).eq("id",member.data.profile_id)
          :Promise.resolve({error:null}),
        member.data.profile_id
          ?db.from("staff_candidates").update({status:"available",interview_status:"not_started"}).eq("profile_id",member.data.profile_id)
          :Promise.resolve({error:null}),
        member.data.profile_id
          ?db.from("player_staff_assignments").update({active:false,end_date:fireDate,ended_reason:"Licencié de l’académie"}).eq("staff_profile_id",member.data.profile_id).eq("active",true)
          :Promise.resolve({error:null})
      ]);
      const err=del.error||car.error||contracts.error||profileUp.error||candUp.error||assignmentUp.error;
      if(err)return h({error:err.message},500);

      if(member.data.profile_id){
        const existing=await db.from("staff_candidates").select("id").eq("profile_id",member.data.profile_id).maybeSingle();
        if(!existing.error&&!existing.data){
          const profile=await db.from("staff_profiles").select("*").eq("id",member.data.profile_id).maybeSingle();
          if(profile.data){
            const p:any=profile.data;
            const role=String(p.primary_role||"");
            const skill=role.toLowerCase().includes("double")
              ?Number(p.doubles_coaching_rating||p.coach_rating||10)
              :role.toLowerCase().includes("kin")||role.toLowerCase().includes("ost")
              ?Number(p.medical_rating||10)
              :role.toLowerCase().includes("phys")
                ?Number(p.fitness_rating||10)
                :role.toLowerCase().includes("recrut")||role.toLowerCase().includes("scout")
                  ?Number(p.scouting_rating||10)
                  :role.toLowerCase().includes("anal")
                    ?Math.max(Number(p.tactical_rating||10),Number(p.scouting_rating||10))
                    :role.toLowerCase().includes("mental")
                      ?Number(p.mental_rating||10)
                      :Number(p.coach_rating||10);
            await db.from("staff_candidates").insert({
              name:p.name,role:p.primary_role,skill,
              weekly_cost:p.asking_weekly_cost,
              signing_cost:Math.round(Number(p.asking_weekly_cost||0)*(1.5+Number(p.reputation||10)/20)),
              specialty:p.specialty,status:"available",profile_id:p.id
            });
          }
        }
      }

      const agentSync=/agent/i.test(String(member.data.role||""))
        ?await db.rpc("sync_managed_agent_representation",{p_date:fireDate})
        :{data:null,error:null};
      await db.from("inbox_items").insert({kind:"staff",title:"Départ du staff",body:(member.data.name||member.data.role)+" quitte ton équipe. Indemnité : "+severance+" €.",action_route:"staff",is_read:false});
      if(/agent/i.test(String(member.data.role||""))&&!agentSync.error){
        await db.from("inbox_items").insert({kind:"commercial",title:"Représentation à revoir",body:"Ton agent a quitté l'équipe. Tu peux recruter un nouvel agent depuis le marché du staff.",action_route:"staff",is_read:false});
      }
      return h({ok:true,budget,severance,agent_representation:agentSync.error?{error:agentSync.error.message}:agentSync.data});
    }

    if(action==="mediate_staff_conflict"){
      const aId=n(body?.staff_a_id,0,1,99999999),bId=n(body?.staff_b_id,0,1,99999999);
      if(!aId||!bId||aId===bId)return h({error:"Relation staff invalide."},400);
      const lo=Math.min(aId,bId),hi=Math.max(aId,bId);
      const own=await db.from("staff").select("profile_id").in("profile_id",[lo,hi]);
      if(own.error)return h({error:own.error.message},500);
      if((own.data??[]).length<2)return h({error:"La médiation concerne uniquement les membres de ton staff."},409);
      const rel=await db.from("staff_peer_relationships").select("*").eq("staff_a_id",lo).eq("staff_b_id",hi).maybeSingle();
      if(rel.error||!rel.data)return h({error:rel.error?.message||"Relation staff introuvable."},404);
      const profiles=await db.from("staff_profiles").select("id,name,communication_rating,professionalism,adaptability_rating").in("id",[lo,hi]);
      if(profiles.error)return h({error:profiles.error.message},500);
      const ps=profiles.data??[];
      const avgCom=ps.length?ps.reduce((s:number,x:any)=>s+Number(x.communication_rating||10)+Number(x.adaptability_rating||10),0)/(ps.length*2):10;
      const reduction=Math.max(14,Math.min(34,Math.round(10+avgCom*.9)));
      const newConflict=Math.max(0,Number(rel.data.conflict_score||0)-reduction);
      const newAffinity=Math.min(100,Number(rel.data.affinity||50)+Math.round(reduction*.45));
      const newTrust=Math.min(100,Number(rel.data.trust||50)+Math.round(reduction*.35));
      const today=String(career.data.career_date||AGE_REFERENCE_DATE);
      const relUp=await db.from("staff_peer_relationships").update({
        conflict_score:newConflict,
        rivalry:Math.max(0,Number(rel.data.rivalry||0)-Math.round(reduction*.30)),
        affinity:newAffinity,trust:newTrust,
        relation_type:newConflict>=60?"Tension":newConflict>=30?"Collègues":"Bonne entente",
        last_update:today
      }).eq("staff_a_id",lo).eq("staff_b_id",hi);
      if(relUp.error)return h({error:relUp.error.message},500);
      const managedId=Number(career.data.managed_player_id||0);
      {
        const links=await db.from("player_staff_assignments")
          .select("id,satisfaction,team_chemistry,trust,affinity")
          .eq("active",true).in("staff_profile_id",[lo,hi]);
        if(!links.error){
          for(const x of links.data??[]){
            await db.from("player_staff_assignments").update({
              satisfaction:Math.min(100,Number(x.satisfaction||70)+8),
              team_chemistry:Math.min(100,Number(x.team_chemistry||70)+12),
              trust:Math.min(100,Number(x.trust||70)+5),
              affinity:Math.min(100,Number(x.affinity||70)+4),
              last_review_date:today
            }).eq("id",x.id);
          }
        }
      }
      for(const sp of ps){
        await db.from("staff_career_events").insert({
          staff_profile_id:sp.id,event_date:today,event_type:"conflict_mediated",
          player_id:null,
          description:"Médiation interne de l’académie : conflit réduit de "+reduction+" points."
        });
      }
      await db.from("inbox_items").insert({kind:"staff",title:"Médiation du staff",body:"La tension interne baisse à "+newConflict+"/100.",action_route:"staff",is_read:false});
      return h({ok:true,conflict_score:newConflict,reduction,affinity:newAffinity,trust:newTrust});
    }

    if(action==="rest_staff"){
      const member=await db.from("staff").select("id,name,role,profile_id").eq("id",id).maybeSingle();
      if(member.error||!member.data)return h({error:member.error?.message||"Membre du staff introuvable"},404);
      if(!member.data.profile_id)return h({error:"Ce membre n'a pas de profil staff complet."},409);
      const today=String(career.data.career_date||AGE_REFERENCE_DATE);
      const until=new Date(today+"T12:00:00Z");until.setUTCDate(until.getUTCDate()+14);
      const profile=await db.from("staff_profiles").select("burnout,travel_fatigue,energy,operational_status,rest_until").eq("id",member.data.profile_id).maybeSingle();
      if(profile.error||!profile.data)return h({error:profile.error?.message||"Profil introuvable"},404);
      if(String(profile.data.operational_status||"active")==="rest"&&String(profile.data.rest_until||"")>=today)return h({error:"Ce membre est déjà au repos."},409);
      const up=await db.from("staff_profiles").update({
        operational_status:"rest",
        rest_until:until.toISOString().slice(0,10),
        burnout:Math.max(0,Number(profile.data.burnout||0)-18),
        travel_fatigue:Math.max(0,Number(profile.data.travel_fatigue||0)-22),
        energy:Math.min(100,Number(profile.data.energy||70)+24),
        updated_at:new Date().toISOString()
      }).eq("id",member.data.profile_id);
      if(up.error)return h({error:up.error.message},500);
      await db.from("staff_career_events").insert({
        staff_profile_id:member.data.profile_id,event_date:today,event_type:"rest_period",
        player_id:null,role:member.data.role,
        description:"Deux semaines de récupération du staff de l’académie pour réduire fatigue professionnelle et surcharge."
      });
      await db.from("inbox_items").insert({kind:"staff",title:"Repos du staff",body:(member.data.name||member.data.role)+" est mis au repos jusqu'au "+until.toISOString().slice(0,10)+".",action_route:"staff",is_read:false});
      return h({ok:true,rest_until:until.toISOString().slice(0,10)});
    }

    if(action==="match_staff_offer"){
      const offer=await db.from("user_staff_external_offers").select("*,staff:staff_profiles(*)").eq("id",id).maybeSingle();
      if(offer.error||!offer.data)return h({error:offer.error?.message||"Offre introuvable"},404);
      if(offer.data.status!=="pending")return h({error:"Cette offre n'est plus active."},409);
      const sp:any=Array.isArray(offer.data.staff)?offer.data.staff[0]:offer.data.staff||{};
      const member=await db.from("staff").select("*").eq("profile_id",offer.data.staff_profile_id).maybeSingle();
      if(member.error||!member.data)return h({error:"Ce membre n'est plus dans ton staff."},409);

      const bonus=Math.round(Number(offer.data.offered_weekly||0)*2);
      if(budget<bonus)return h({error:"Budget insuffisant pour la prime de fidélité."},409);
      budget-=bonus;
      const today=String(career.data.career_date||AGE_REFERENCE_DATE);
      const newEnd=new Date(today+"T12:00:00Z");newEnd.setUTCFullYear(newEnd.getUTCFullYear()+2);

      const [staffUp,contractUp,assignmentUp,offerUp,profileUp,careerUp]=await Promise.all([
        db.from("staff").update({weekly_cost:offer.data.offered_weekly}).eq("id",member.data.id),
        db.from("contracts").update({
          weekly_salary:offer.data.offered_weekly,
          end_date:newEnd.toISOString().slice(0,10),
          status:"active"
        }).eq("subject_type","staff").eq("subject_name",member.data.name).eq("status","active"),
        db.from("player_staff_assignments").update({
          weekly_salary:offer.data.offered_weekly,
          contract_end:newEnd.toISOString().slice(0,10),
          trust:Math.min(100,75+Number(sp.loyalty||10)),
          satisfaction:Math.min(100,78+Math.round(Number(sp.loyalty||10)/2)),
          last_review_date:today
        }).eq("staff_profile_id",offer.data.staff_profile_id).eq("active",true),
        db.from("user_staff_external_offers").update({status:"matched"}).eq("id",id),
        db.from("staff_profiles").update({loyalty:Math.min(20,Number(sp.loyalty||10)+1),updated_at:new Date().toISOString()}).eq("id",offer.data.staff_profile_id),
        db.from("career_state").update({budget,updated_at:new Date().toISOString()}).eq("id","demo")
      ]);
      const err=staffUp.error||contractUp.error||assignmentUp.error||offerUp.error||profileUp.error||careerUp.error;
      if(err)return h({error:err.message},500);

      await db.from("staff_career_events").insert({
        staff_profile_id:offer.data.staff_profile_id,event_date:today,event_type:"retained_after_offer",
        player_id:null,role:member.data.role,
        description:"A choisi de rester dans l’académie après une revalorisation alignée sur une offre concurrente."
      });
      await db.from("inbox_items").update({decision_status:"resolved",is_read:true})
        .eq("related_entity_type","staff_external_offer").eq("related_entity_id",id);
      await db.from("inbox_items").insert({kind:"staff",title:"Staff conservé",body:member.data.name+" reste dans ton équipe après revalorisation. Prime de fidélité : "+bonus+" €.",action_route:"staff",is_read:false});
      return h({ok:true,budget,weekly_salary:offer.data.offered_weekly,contract_end:newEnd.toISOString().slice(0,10),bonus});
    }

    if(action==="release_staff_offer"){
      const offer=await db.from("user_staff_external_offers").select("*,staff:staff_profiles(*)").eq("id",id).maybeSingle();
      if(offer.error||!offer.data)return h({error:offer.error?.message||"Offre introuvable"},404);
      if(offer.data.status!=="pending")return h({error:"Cette offre n'est plus active."},409);
      const sp:any=Array.isArray(offer.data.staff)?offer.data.staff[0]:offer.data.staff||{};
      const member=await db.from("staff").select("*").eq("profile_id",offer.data.staff_profile_id).maybeSingle();
      const today=String(career.data.career_date||AGE_REFERENCE_DATE);

      if(member.data){
        await db.from("staff").delete().eq("id",member.data.id);
        await db.from("contracts").update({status:"terminated"}).eq("subject_type","staff").eq("subject_name",member.data.name).eq("status","active");
      }
      await db.from("player_staff_assignments").update({
        active:false,end_date:today,ended_reason:"Départ accepté après offre extérieure"
      }).eq("staff_profile_id",offer.data.staff_profile_id).eq("active",true);

      const fit=await db.rpc("staff_fit_score",{p_player_id:offer.data.competitor_player_id,p_staff_id:offer.data.staff_profile_id,p_role:sp.primary_role||member.data?.role||"Coach"});
      const fitValue=Array.isArray(fit.data)?Number(fit.data[0]||60):Number(fit.data||60);
      await db.from("player_staff_assignments").insert({
        player_id:offer.data.competitor_player_id,staff_profile_id:offer.data.staff_profile_id,
        role:sp.primary_role||member.data?.role||"Coach",start_date:today,active:true,verified:false,
        affinity:70,trust:68,source_label:"Court Boss · offre extérieure acceptée",snapshot_date:today,
        notes:"Départ du staff du joueur géré après offre extérieure.",weekly_salary:offer.data.offered_weekly,
        contract_end:new Date(new Date(today+"T12:00:00Z").setUTCFullYear(new Date(today+"T12:00:00Z").getUTCFullYear()+2)).toISOString().slice(0,10),
        assignment_generation:1,last_review_date:today,role_fit:fitValue,satisfaction:74,team_chemistry:72
      });
      await Promise.all([
        db.from("user_staff_external_offers").update({status:"accepted_user_release"}).eq("id",id),
        db.from("staff_profiles").update({market_status:"contracted",available_from:null}).eq("id",offer.data.staff_profile_id),
        db.from("staff_candidates").update({status:"unavailable"}).eq("profile_id",offer.data.staff_profile_id)
      ]);
      await db.from("staff_career_events").insert({
        staff_profile_id:offer.data.staff_profile_id,event_date:today,event_type:"left_user_for_offer",
        player_id:offer.data.competitor_player_id,other_player_id:null,
        role:sp.primary_role||member.data?.role||"Staff",
        description:"Le joueur géré a accepté son départ après une offre extérieure."
      });
      await db.from("inbox_items").update({decision_status:"resolved",is_read:true})
        .eq("related_entity_type","staff_external_offer").eq("related_entity_id",id);
      await db.from("inbox_items").insert({kind:"staff",title:"Départ du staff",body:(sp.name||member.data?.name||"Un membre du staff")+" rejoint un autre joueur.",action_route:"staff",is_read:false});
      return h({ok:true,status:"departed"});
    }

    if(action==="update_season_plan"){
      const primaryId=Number(career.data.managed_player_id||0);
      const managedId=n(body?.player_id,primaryId,1,99999999);
      if(!managedId)return h({error:"Joueur géré introuvable"},409);
      let focus=String(career.data.career_focus||"mixed");
      if(managedId!==primaryId){
        const roster=await db.from("academy_roster").select("id").eq("player_id",managedId).eq("status","active").maybeSingle();
        const player=await db.from("players").select("career_focus").eq("id",managedId).maybeSingle();
        if(roster.error||player.error)return h({error:(roster.error||player.error)?.message},500);
        if(!roster.data||!player.data)return h({error:"Ce joueur ne fait pas partie du groupe géré."},403);
        focus=String(player.data.career_focus||"mixed");
      }
      const season=Number(String(career.data.career_date||AGE_REFERENCE_DATE).slice(0,4));
      const incoming=body?.plan&&typeof body.plan==="object"?body.plan:{};
      const allowedSurfaces=new Set(["Dur","Terre","Gazon","Mixte","Indoor"]);
      const allowedPlans=new Set(["balanced","elite_selective","tour_regular","challenger_push","itf_build","doubles_specialist","singles_specialist","junior_transition","ncaa_pathway"]);
      const current=await db.from("player_season_plans").select("*").eq("player_id",managedId).eq("season",season).maybeSingle();
      if(current.error)return h({error:current.error.message},500);
      const base=current.data||{
        player_id:managedId,season,
        plan_type:focus==="doubles_only"?"doubles_specialist":focus==="singles_only"?"singles_specialist":"balanced",
        target_events:22,preferred_surface:"Dur",secondary_surface:"Terre",
        rest_bias:10,travel_tolerance:10,prestige_bias:10,development_bias:10,doubles_bias:focus==="doubles_only"?18:focus==="singles_only"?2:10,
        reason:"Plan manager Court Boss"
      };
      const normalizedPreferred=String(incoming.preferred_surface||base.preferred_surface||"Dur")==="Polyvalent"?"Mixte":String(incoming.preferred_surface||base.preferred_surface||"Dur");
      const normalizedSecondary=String(incoming.secondary_surface||base.secondary_surface||"Terre")==="Polyvalent"?"Mixte":String(incoming.secondary_surface||base.secondary_surface||"Terre");
      const requestedPlan=String(incoming.plan_type||base.plan_type||"balanced");
      const row={
        ...base,
        plan_type:allowedPlans.has(requestedPlan)?requestedPlan:String(base.plan_type||"balanced"),
        target_events:n(incoming.target_events,Number(base.target_events||22),8,38),
        preferred_surface:allowedSurfaces.has(normalizedPreferred)?normalizedPreferred:String(base.preferred_surface||"Dur"),
        secondary_surface:allowedSurfaces.has(normalizedSecondary)?normalizedSecondary:String(base.secondary_surface||"Terre"),
        rest_bias:n(incoming.rest_bias,Number(base.rest_bias||10),1,20),
        travel_tolerance:n(incoming.travel_tolerance,Number(base.travel_tolerance||10),1,20),
        prestige_bias:n(incoming.prestige_bias,Number(base.prestige_bias||10),1,20),
        development_bias:n(incoming.development_bias,Number(base.development_bias||10),1,20),
        doubles_bias:n(incoming.doubles_bias,Number(base.doubles_bias||10),1,20),
        max_consecutive_weeks:n(incoming.max_consecutive_weeks,Number(base.max_consecutive_weeks||3),1,8),
        rest_trigger_fatigue:n(incoming.rest_trigger_fatigue,Number(base.rest_trigger_fatigue||58),30,90),
        schedule_risk_tolerance:n(incoming.schedule_risk_tolerance,Number(base.schedule_risk_tolerance||10),0,20),
        mental_load_target:n(incoming.mental_load_target,Number(base.mental_load_target||10),0,20),
        reason:String(incoming.reason||"Plan défini par le manager").slice(0,300),
        updated_at:new Date().toISOString(),
        last_adapted_date:String(career.data.career_date||AGE_REFERENCE_DATE)
      };
      const up=await db.from("player_season_plans").upsert(row,{onConflict:"player_id,season"}).select("*").single();
      if(up.error)return h({error:up.error.message},500);
      await db.from("inbox_items").insert({
        kind:"planning",title:"Plan de saison mis à jour",
        body:"Le plan "+season+" a été modifié : "+row.target_events+" tournois cible, priorité "+row.preferred_surface+".",
        action_route:"season",game_date:String(career.data.career_date||AGE_REFERENCE_DATE),priority:"normal",is_read:false
      });
      return h({ok:true,season_plan:up.data});
    }

    if(action==="decline_sponsor"){
      const offer=await db.from("sponsor_offers").select("*").eq("id",id).maybeSingle();
      if(offer.error||!offer.data)return h({error:offer.error?.message||"Offer not found"},404);
      if(!["available","pending"].includes(String(offer.data.status||"")))return h({error:"Offre indisponible"},409);
      const up=await db.from("sponsor_offers").update({status:"declined"}).eq("id",id);
      if(up.error)return h({error:up.error.message},500);
      await db.from("inbox_items").update({decision_status:"resolved",is_read:true})
        .eq("related_entity_type","sponsor_offer").eq("related_entity_id",id);
      return h({ok:true,status:"declined"});
    }

    if(action==="accept_sponsor"){
      const offer=await db.from("sponsor_offers").select("*").eq("id",id).maybeSingle();
      if(offer.error||!offer.data)return h({error:offer.error?.message||"Offer not found"},404);
      if(offer.data.status!=="available")return h({error:"Offre indisponible"},409);

      const agent=await db.from("staff")
        .select("profile:staff_profiles(negotiation_rating,reputation,professionalism,workload,burnout,travel_fatigue)")
        .ilike("role","%Agent%").limit(1).maybeSingle();
      const ap:any=Array.isArray(agent.data?.profile)?agent.data.profile[0]:agent.data?.profile||{};
      const agentEfficiency=Math.max(.68,Math.min(1.06,
        1-Number(ap.burnout||0)*.0032-Number(ap.travel_fatigue||0)*.0018-Math.max(0,Number(ap.workload||20)-75)*.0015+Math.max(0,Number(ap.professionalism||10)-14)*.006
      ));
      const negotiation=Number(ap.negotiation_rating||10)*agentEfficiency,agentRep=Number(ap.reputation||10);
      const negotiationMult=Math.min(1.18,1+Math.max(0,negotiation-10)*.012+Math.max(0,agentRep-10)*.004);
      const focus=String(career.data.career_focus||"mixed");
      const visibilityRank=focus==="doubles_only"
        ?Number(career.data.doubles_rank||999999)
        :(focus==="singles_only"||focus==="singles_priority")
          ?Number(career.data.singles_rank||999999)
          :Math.min(Number(career.data.singles_rank||999999),Number(career.data.doubles_rank||999999));
      const visibilityMult=visibilityRank<=10?1.18:visibilityRank<=50?1.10:visibilityRank<=100?1.05:visibilityRank<=300?1.00:visibilityRank<=800?.94:.88;
      const negotiatedWeekly=Math.round(Number(offer.data.weekly_value||0)*negotiationMult*visibilityMult);
      const negotiatedBonus=Math.round(Number(offer.data.signing_bonus||0)*negotiationMult*visibilityMult);
      const acceptedOn=String(career.data.career_date||AGE_REFERENCE_DATE);
      const sponsorDuration=Math.max(1,Number(offer.data.duration_weeks||52));
      const sponsorEndDate=new Date(acceptedOn+"T12:00:00Z");
      sponsorEndDate.setUTCDate(sponsorEndDate.getUTCDate()+sponsorDuration*7);
      const endsOn=sponsorEndDate.toISOString().slice(0,10);

      budget+=negotiatedBonus;
      const [up,car]=await Promise.all([
        db.from("sponsor_offers").update({
          status:"accepted",weekly_value:negotiatedWeekly,signing_bonus:negotiatedBonus,
          accepted_on:acceptedOn,starts_on:acceptedOn,ends_on:endsOn,weeks_paid:0,ended_on:null
        }).eq("id",id),
        db.from("career_state").update({budget,updated_at:new Date().toISOString()}).eq("id","demo")
      ]);
      if(up.error||car.error)return h({error:(up.error||car.error)?.message},500);
      await db.from("inbox_items").update({decision_status:"resolved",is_read:true})
        .eq("related_entity_type","sponsor_offer").eq("related_entity_id",id);
      await db.from("inbox_items").insert({
        kind:"commercial",title:"Sponsor signé",
        body:"Accord signé avec "+offer.data.brand+". Ton agent négocie "+negotiatedBonus+" € de bonus et "+negotiatedWeekly+" €/sem. pendant "+sponsorDuration+" semaines, jusqu’au "+endsOn+".",
        action_route:"finance",is_read:false
      });
      await recordFinanceTransactions([{
        transaction_key:"sponsor:"+id+":signing",game_date:String(career.data.career_date||AGE_REFERENCE_DATE),week:Number(career.data.week||1),
        category:"sponsor_bonus",amount:negotiatedBonus,source_type:"sponsor_offer",source_id:id,
        description:"Prime de signature · "+String(offer.data.brand),balance_after:budget,
        metadata:{weekly_value:negotiatedWeekly,visibility_rank:visibilityRank,duration_weeks:sponsorDuration,starts_on:acceptedOn,ends_on:endsOn}
      }]);
      return h({ok:true,budget,status:"accepted",weekly_value:negotiatedWeekly,signing_bonus:negotiatedBonus,duration_weeks:sponsorDuration,starts_on:acceptedOn,ends_on:endsOn,weeks_paid:0,agent_bonus_pct:Math.round((negotiationMult-1)*100),visibility_rank:visibilityRank,career_focus:focus});
    }

    if(action==="renew_contract"){
      const con=await db.from("contracts").select("*").eq("id",id).maybeSingle();
      if(con.error||!con.data)return h({error:con.error?.message||"Contract not found"},404);
      const d=new Date((con.data.end_date||"2025-12-31")+"T12:00:00Z");d.setUTCFullYear(d.getUTCFullYear()+1);

      let factor=1.08;
      if(String(con.data.subject_type||"")==="staff"){
        const sm=await db.from("staff")
          .select("profile:staff_profiles(ambition,loyalty,negotiation_rating,reputation)")
          .eq("name",con.data.subject_name).maybeSingle();
        const p:any=Array.isArray(sm.data?.profile)?sm.data.profile[0]:sm.data?.profile||{};
        factor=Math.max(1.03,Math.min(1.25,
          1.04
          +Number(p.ambition||10)*.005
          +Number(p.negotiation_rating||10)*.004
          +Number(p.reputation||10)*.003
          -Number(p.loyalty||10)*.003
        ));
      }

      const salary=Math.round(Number(con.data.weekly_salary||0)*factor);
      const up=await db.from("contracts").update({end_date:d.toISOString().slice(0,10),weekly_salary:salary,status:"active"}).eq("id",id);
      if(up.error)return h({error:up.error.message},500);

      if(String(con.data.subject_type||"")==="staff"){
        await db.from("staff").update({weekly_cost:salary}).eq("name",con.data.subject_name);
      }
      await db.from("inbox_items").update({decision_status:"resolved",is_read:true})
        .eq("related_entity_type","contract").eq("related_entity_id",id);
      return h({ok:true,end_date:d.toISOString().slice(0,10),weekly_salary:salary,raise_pct:Math.round((factor-1)*100)});
    }

    if(action==="approach_partner"){
      const primaryId=Number(career.data.managed_player_id||0);
      const managedId=n(body?.player_id,primaryId,1,99999999);
      if(!managedId)return h({error:"Joueur géré introuvable"},409);
      if(managedId!==primaryId){
        const roster=await db.from("academy_roster").select("id").eq("player_id",managedId).eq("status","active").maybeSingle();
        if(roster.error)return h({error:roster.error.message},500);
        if(!roster.data)return h({error:"Ce joueur ne fait pas partie du groupe géré."},403);
      }
      const source=await db.from("players").select("id,name,career_focus").eq("id",managedId).maybeSingle();
      if(source.error||!source.data)return h({error:source.error?.message||"Joueur géré introuvable"},404);
      if(String(source.data.career_focus||(managedId===primaryId?career.data.career_focus:"mixed")||"mixed")==="singles_only"){
        return h({error:"Orientation Simple exclusivement : les projets de double sont désactivés."},409);
      }
      if(Number(id)===managedId)return h({error:"Impossible de se choisir soi-même comme partenaire."},409);

      const target=await db.from("players")
        .select("id,name,country,doubles_ranking,career_focus,career_status")
        .eq("id",id).maybeSingle();
      if(target.error||!target.data)return h({error:target.error?.message||"Joueur introuvable"},404);
      if(target.data.career_status!=="active"||target.data.doubles_ranking==null||String(target.data.career_focus||"mixed")==="singles_only"){
        return h({error:"Ce joueur n'est pas disponible pour un projet double."},409);
      }

      const today=String(career.data.career_date||AGE_REFERENCE_DATE);
      const interest=await db.rpc("doubles_partner_interest",{
        p_from_player_id:managedId,p_to_player_id:Number(id),p_date:today
      });
      if(interest.error)return h({error:interest.error.message},500);
      const x:any=(interest.data??[])[0];
      if(!x)return h({error:"Impossible d'évaluer cette association."},409);

      const accepted=Boolean(x.accepted_now);
      const offer=await db.from("doubles_partner_offers").insert({
        from_player_id:managedId,to_player_id:Number(id),
        season:Number(today.slice(0,4)),offer_date:today,expires_at:today,
        response_date:today,direction:"outgoing",
        status:accepted?"accepted":"declined",
        interest_score:Number(x.interest_score||0),
        acceptance_threshold:Number(x.acceptance_threshold||60),
        chemistry:Number(x.chemistry||0),compatibility:Number(x.compatibility||0),
        pair_strength:Number(x.pair_strength||0),
        proposed_commitment:Math.max(55,Math.min(100,Math.round(Number(x.affinity_score||0))+4)),
        current_partner_id:x.current_partner_id||null,
        current_partner_commitment:x.current_partner_commitment||null,
        reason:String(x.reason||""),source_label:"Utilisateur · approche partenaire double"
      }).select("id").single();
      if(offer.error)return h({error:offer.error.message},500);

      let partnership:any=null;
      if(accepted){
        const active=await db.rpc("activate_player_doubles_partner",{
          p_player_id:managedId,p_partner_id:Number(id),p_date:today,p_source:"Utilisateur · approche acceptée"
        });
        if(active.error)return h({error:active.error.message},500);
        partnership=active.data;
      }

      await db.from("inbox_items").insert({
        kind:"double",
        title:accepted?"Proposition de double acceptée":"Proposition de double refusée",
        body:String(target.data.name)+(accepted
          ?" accepte de devenir le partenaire principal de "+String(source.data.name||"ce joueur")+"."
          :" refuse pour le moment. "+String(x.reason||"")),
        action_route:"doubles",is_read:false,
        related_entity_type:"player",related_entity_id:managedId,
        action_payload:{route:"doubles",player_id:managedId}
      });

      return h({
        ok:true,accepted,player_id:managedId,
        offer_id:offer.data.id,interest_score:Number(x.interest_score||0),
        threshold:Number(x.acceptance_threshold||60),reason:String(x.reason||""),partnership
      });
    }

    if(action==="respond_partner_offer"){
      const decision=String(body?.decision||"decline").toLowerCase();
      if(!["accept","decline"].includes(decision))return h({error:"Décision invalide"},400);

      const offer=await db.from("doubles_partner_offers")
        .select("*,from_player:players!doubles_partner_offers_from_player_id_fkey(id,name,country,doubles_ranking,career_focus),to_player:players!doubles_partner_offers_to_player_id_fkey(id,name,country,doubles_ranking,career_focus)")
        .eq("id",id).eq("direction","incoming").maybeSingle();
      if(offer.error||!offer.data)return h({error:offer.error?.message||"Proposition introuvable"},404);
      if(offer.data.status!=="pending")return h({error:"Cette proposition n'est plus disponible."},409);

      const primaryId=Number(career.data.managed_player_id||0);
      const managedId=Number(offer.data.to_player_id||0);
      if(!managedId)return h({error:"Destinataire managé introuvable"},409);
      if(managedId!==primaryId){
        const roster=await db.from("academy_roster").select("id").eq("player_id",managedId).eq("status","active").maybeSingle();
        if(roster.error)return h({error:roster.error.message},500);
        if(!roster.data)return h({error:"Cette proposition ne concerne plus un joueur du groupe géré."},403);
      }
      const managedFocus=String(offer.data.to_player?.career_focus||(managedId===primaryId?career.data.career_focus:"mixed")||"mixed");
      if(managedFocus==="singles_only"){
        return h({error:"Orientation Simple exclusivement : les propositions de double sont désactivées pour ce joueur."},409);
      }

      const today=String(career.data.career_date||AGE_REFERENCE_DATE);
      if(String(offer.data.expires_at)<today){
        await db.from("doubles_partner_offers").update({status:"expired",response_date:today}).eq("id",id);
        return h({error:"Cette proposition a expiré."},409);
      }

      let partnership:any=null;
      if(decision==="accept"){
        const active=await db.rpc("activate_player_doubles_partner",{
          p_player_id:managedId,
          p_partner_id:Number(offer.data.from_player_id),
          p_date:today,
          p_source:"Utilisateur · proposition entrante acceptée"
        });
        if(active.error)return h({error:active.error.message},500);
        partnership=active.data;
      }

      const up=await db.from("doubles_partner_offers").update({
        status:decision==="accept"?"accepted":"declined",response_date:today
      }).eq("id",id);
      if(up.error)return h({error:up.error.message},500);

      if(decision==="accept"){
        await db.from("doubles_partner_offers").update({
          status:"withdrawn",response_date:today
        }).eq("to_player_id",managedId).eq("direction","incoming").eq("status","pending").neq("id",id);
      }

      await db.from("inbox_items").update({decision_status:"resolved",is_read:true})
        .eq("related_entity_type","doubles_partner_offer").eq("related_entity_id",id);
      await db.from("inbox_items").insert({
        kind:"double",
        title:decision==="accept"?"Nouveau partenaire principal":"Proposition refusée",
        body:decision==="accept"
          ?String(offer.data.from_player?.name||"Le joueur")+" devient le partenaire principal de "+String(offer.data.to_player?.name||"ce joueur")+"."
          :"Proposition de "+String(offer.data.from_player?.name||"ce joueur")+" refusée.",
        action_route:"doubles",is_read:false,
        related_entity_type:"player",related_entity_id:managedId,
        action_payload:{route:"doubles",player_id:managedId}
      });

      return h({ok:true,player_id:managedId,status:decision==="accept"?"accepted":"declined",partnership});
    }

    if(action==="choose_partner"){
      const primaryId=Number(career.data.managed_player_id||0);
      const managedId=n(body?.player_id,primaryId,1,99999999);
      const [managed,roster,partner]=await Promise.all([
        db.from("players").select("id,name,career_focus").eq("id",managedId).maybeSingle(),
        managedId===primaryId
          ?Promise.resolve({data:{id:0},error:null} as any)
          :db.from("academy_roster").select("id").eq("player_id",managedId).eq("status","active").maybeSingle(),
        db.from("players").select("id,name,current_ability,doubles_ranking,career_focus,career_status").eq("id",id).maybeSingle()
      ]);
      if(managed.error||roster.error||partner.error)return h({error:(managed.error||roster.error||partner.error)?.message},500);
      if(!managed.data||!roster.data)return h({error:"Ce joueur ne fait pas partie du groupe géré."},403);
      if(!partner.data)return h({error:"Joueur introuvable"},404);
      if(String(managed.data.career_focus||"mixed")==="singles_only"){
        return h({error:"Orientation Simple exclusivement : choisis d'abord une autre orientation pour former une paire."},409);
      }
      if(Number(managedId)===Number(id))return h({error:"Impossible de se choisir soi-même comme partenaire."},409);
      if(partner.data.career_status!=="active"||partner.data.doubles_ranking==null||String(partner.data.career_focus||"mixed")==="singles_only"){
        return h({error:"Ce joueur n'est pas disponible pour un projet double."},409);
      }

      const today=String(career.data.career_date||AGE_REFERENCE_DATE);
      const active=await db.rpc("activate_managed_doubles_partner",{
        p_player_id:managedId,p_partner_id:Number(id),p_date:today,
        p_source:"Utilisateur · partenaire double"
      });
      if(active.error)return h({error:active.error.message},500);

      const withdraw=await db.from("managed_doubles_entries").update({
        status:"withdrawn",withdrawn_on:today,updated_at:new Date().toISOString()
      }).eq("owner_id","demo").eq("player_id",managedId).eq("status","entered").neq("partner_id",Number(id));
      if(withdraw.error)return h({error:withdraw.error.message},500);

      return h({...active.data,ok:true,player_id:managedId,primary_partner:true});
    }

    if(action==="davis_role"){
      const role=String(body?.role||"Réserve").slice(0,40);
      const targetPlayerId=Number(id||0);
      const primaryId=Number(career.data.managed_player_id||0);
      let managedFocus:string|null=null;

      if(targetPlayerId===primaryId){
        managedFocus=String(career.data.career_focus||"mixed");
      }else if(targetPlayerId){
        const roster=await db.from("academy_roster")
          .select("id").eq("player_id",targetPlayerId).eq("status","active").maybeSingle();
        if(roster.error)return h({error:roster.error.message},500);
        if(roster.data){
          const p=await db.from("players").select("career_focus").eq("id",targetPlayerId).maybeSingle();
          if(p.error)return h({error:p.error.message},500);
          managedFocus=String(p.data?.career_focus||"mixed");
        }
      }

      if(managedFocus==="doubles_only"&&/^Simple/i.test(role)){
        return h({error:"Orientation Double exclusivement : ce joueur ne peut pas être aligné en simple en Coupe Davis."},409);
      }
      if(managedFocus==="singles_only"&&/^Double/i.test(role)){
        return h({error:"Orientation Simple exclusivement : ce joueur ne peut pas être aligné en double en Coupe Davis."},409);
      }

      const nation=String(career.data.selected_federation_nation||career.data.federation_nation||"FRA").toUpperCase();
      const up=await db.from("davis_squad").update({role}).eq("player_id",targetPlayerId).eq("nation",nation);
      if(up.error)return h({error:up.error.message},500);
      return h({ok:true,role,nation,player_id:targetPlayerId,managed_focus:managedFocus});
    }


    if(action==="commit_college"){
      const target=await resolveActionManagedPlayer(body?.player_id);
      if(target.error)return h({error:target.error},target.status);
      const managedId=target.playerId;
      const ensure=await db.rpc("ensure_player_college_state",{p_player_id:managedId});
      if(ensure.error)return h({error:ensure.error.message},500);
      const stateId=String((ensure.data as any)?.state_id||(target.isPrimary?"demo":"player:"+managedId));

      const offer=await db.from("college_offers")
        .select("*,team:college_teams(*)").eq("id",id).eq("player_id",managedId).maybeSingle();
      if(offer.error||!offer.data)return h({error:offer.error?.message||"Offre introuvable pour ce joueur"},404);

      const playerAge=Number(target.player?.age||0);
      if(playerAge&&playerAge<18)return h({error:"Entrée NCAA impossible avant 18 ans."},409);
      if(playerAge>22)return h({error:"Ce joueur est trop âgé pour débuter une carrière NCAA."},409);

      const currentState=await db.from("college_career_state").select("*").eq("id",stateId).maybeSingle();
      if(currentState.error)return h({error:currentState.error.message},500);
      if(["committed","active"].includes(String(currentState.data?.status||""))){
        return h({error:"Ce joueur est déjà engagé dans une université."},409);
      }

      const today=String(career.data.career_date||new Date().toISOString().slice(0,10));
      const season=String(new Date(today+"T12:00:00Z").getUTCFullYear());
      const school=String(offer.data.team?.name||"Université");
      const playerName=String(target.player?.name||"Le joueur");

      const [decline,o,stateUp,playerUp,ncaaUp]=await Promise.all([
        db.from("college_offers").update({status:"declined"}).eq("player_id",managedId).neq("id",id).eq("status","available"),
        db.from("college_offers").update({status:"accepted"}).eq("id",id).eq("player_id",managedId),
        db.from("college_career_state").update({
          chosen_team_id:offer.data.team_id,scholarship_pct:offer.data.scholarship_pct,
          status:"committed",lineup_position:6,coach_trust:62,player_id:managedId
        }).eq("id",stateId),
        db.from("players").update({
          ncaa_current:true,ncaa_status:"Active",ncaa_last_school:school,
          ncaa_verified:true,ncaa_school:school,ncaa_division:"NCAA Division I"
        }).eq("id",managedId),
        db.from("ncaa_career").upsert({
          player_id:managedId,school,division:"NCAA Division I",
          start_season:season,status:"Active",verified:false,
          source_label:"Court Boss save · engagement NCAA simulé",
          last_verified_at:new Date().toISOString()
        },{onConflict:"player_id"})
      ]);
      const err=decline.error||o.error||stateUp.error||playerUp.error||ncaaUp.error;
      if(err)return h({error:err.message},500);

      await db.from("inbox_items").insert({
        kind:"college",title:"Engagement NCAA · "+playerName,
        body:playerName+" s’engage avec "+school+" ("+offer.data.scholarship_pct+"% de bourse).",
        action_route:"university",is_read:false,
        related_entity_type:"player",related_entity_id:managedId,
        action_payload:{route:"university",player_id:managedId}
      });
      return h({ok:true,player_id:managedId,team:offer.data.team,status:"committed",ncaa_status:"Active",state_id:stateId});
    }

    if(action==="turn_pro_college"){
      const target=await resolveActionManagedPlayer(body?.player_id);
      if(target.error)return h({error:target.error},target.status);
      const managedId=target.playerId;
      const ensure=await db.rpc("ensure_player_college_state",{p_player_id:managedId});
      if(ensure.error)return h({error:ensure.error.message},500);
      const stateId=String((ensure.data as any)?.state_id||(target.isPrimary?"demo":"player:"+managedId));

      const cs=await db.from("college_career_state")
        .select("*,team:college_teams(*)").eq("id",stateId).eq("player_id",managedId).maybeSingle();
      if(cs.error||!cs.data)return h({error:cs.error?.message||"Carrière NCAA introuvable"},404);
      if(!["committed","active"].includes(String(cs.data.status||""))){
        return h({error:"Ce joueur n’est pas actuellement engagé en NCAA."},409);
      }

      const today=String(career.data.career_date||new Date().toISOString().slice(0,10));
      const endSeason=String(new Date(today+"T12:00:00Z").getUTCFullYear());
      const school=String(cs.data.team?.name||target.player?.ncaa_school||"Université");
      const playerName=String(target.player?.name||"Le joueur");

      const [stateUp,playerUp,ncaaUp]=await Promise.all([
        db.from("college_career_state").update({status:"pro"}).eq("id",stateId).eq("player_id",managedId),
        db.from("players").update({
          ncaa_current:false,ncaa_status:"Alumni",ncaa_last_school:school,
          ncaa_verified:true,ncaa_school:null,ncaa_rank:null,
          turned_pro_year:Number(endSeason)
        }).eq("id",managedId),
        db.from("ncaa_career").upsert({
          player_id:managedId,school,division:"NCAA Division I",end_season:endSeason,status:"Alumni",
          departure_date:today,verified:false,source_label:"Court Boss save · passage pro simulé",
          last_verified_at:new Date().toISOString()
        },{onConflict:"player_id"})
      ]);
      const err=stateUp.error||playerUp.error||ncaaUp.error;
      if(err)return h({error:err.message},500);

      await db.from("inbox_items").insert({
        kind:"college",title:"Passage professionnel · "+playerName,
        body:playerName+" quitte "+school+" pour passer professionnel. Son historique NCAA reste archivé.",
        action_route:"university",is_read:false,
        related_entity_type:"player",related_entity_id:managedId,
        action_payload:{route:"university",player_id:managedId}
      });
      return h({ok:true,player_id:managedId,status:"pro",ncaa_status:"Alumni",school,departure_date:today,state_id:stateId});
    }

    if(action==="play_college_dual"){
      const sim=await db.rpc("simulate_ncaa_dual_v2",{p_dual_id:id});
      if(sim.error)return h({error:sim.error.message},500);
      if(sim.data?.ok===false){
        const reason=String(sim.data?.reason||"ncaa_simulation_failed");
        return h({
          error:reason==="insufficient_roster"
            ?"Effectif NCAA insuffisant pour disputer ce dual."
            :"Ce dual NCAA ne peut pas être joué maintenant.",
          details:sim.data
        },409);
      }
      const dual=await db.from("college_duals")
        .select("*,home:college_teams!college_duals_home_team_id_fkey(*),away:college_teams!college_duals_away_team_id_fkey(*)")
        .eq("id",id).maybeSingle();
      if(dual.error||!dual.data)return h({error:dual.error?.message||"Dual not found"},404);
      await db.from("inbox_items").insert({
        kind:"college",
        title:"Résultat NCAA",
        body:String(dual.data.home?.name||"Équipe")+" "+dual.data.home_score+"-"+dual.data.away_score+" "+String(dual.data.away?.name||"Équipe")+".",
        action_route:"university",
        is_read:false
      });
      return h({
        ok:true,
        already:Boolean(sim.data?.already),
        home_score:dual.data.home_score,
        away_score:dual.data.away_score,
        winner_team_id:dual.data.winner_team_id,
        home_win_probability:dual.data.home_win_probability,
        stage:dual.data.stage,
        competition:dual.data.competition
      });
    }


    if(action==="play_davis_tie"){
      const sim=await db.rpc("simulate_davis_tie_v2",{p_tie_id:id});
      if(sim.error)return h({error:sim.error.message},500);
      if(sim.data?.ok===false){
        const reason=String(sim.data?.reason||"davis_simulation_failed");
        return h({
          error:reason==="participants_not_ready"
            ?"Affiche Davis pas encore déterminée."
            :reason==="incomplete_squad"
              ?"Sélection Davis incomplète pour cette rencontre."
              :"Cette rencontre Davis ne peut pas être jouée maintenant.",
          details:sim.data
        },409);
      }
      const [tie,rub]=await Promise.all([
        db.from("davis_ties").select("*").eq("id",id).maybeSingle(),
        db.from("davis_rubbers").select("*").eq("tie_id",id).order("rubber_no")
      ]);
      if(tie.error||rub.error||!tie.data)return h({error:(tie.error||rub.error)?.message||"Tie not found"},500);
      if(!sim.data?.already){
        await db.from("inbox_items").insert({
          kind:"davis",
          title:"Résultat Coupe Davis",
          body:String(tie.data.home_nation)+" "+tie.data.home_score+"-"+tie.data.away_score+" "+String(tie.data.away_nation)+".",
          action_route:"davis",
          is_read:false
        });
      }
      return h({
        ok:true,
        already:Boolean(sim.data?.already),
        tie:tie.data,
        rubbers:rub.data??[],
        winner_nation:sim.data?.winner_nation,
        format:sim.data?.format
      });
    }

    if(action==="set_scouting_assignment"){
      const focus=String(body?.focus||"U23 potentiel").slice(0,80);
      const region=String(body?.region||"").trim().slice(0,80);
      const today=String(career.data.career_date||AGE_REFERENCE_DATE);
      let scoutProfileId=Number(body?.scout_profile_id||0);
      let scoutName="";
      let scoutRating=10;

      if(scoutProfileId){
        const own=await db.from("staff")
          .select("profile_id,name,role,profile:staff_profiles(id,name,scouting_rating)")
          .eq("profile_id",scoutProfileId).maybeSingle();
        if(own.error||!own.data)return h({error:"Ce recruteur ne fait pas partie de ton staff."},409);
        const p:any=Array.isArray(own.data.profile)?own.data.profile[0]:own.data.profile||{};
        scoutName=String(p.name||own.data.name||"Recruteur");
        scoutRating=Number(p.scouting_rating||10);
      }else{
        const own=await db.from("staff")
          .select("profile_id,name,role,profile:staff_profiles(id,name,scouting_rating,reputation)")
          .not("profile_id","is",null);
        if(!own.error&&own.data?.length){
          const ranked=(own.data??[])
            .map((x:any)=>({...x,p:Array.isArray(x.profile)?x.profile[0]:x.profile||{}}))
            .sort((a:any,b:any)=>Number(b.p?.scouting_rating||0)-Number(a.p?.scouting_rating||0)||Number(b.p?.reputation||0)-Number(a.p?.reputation||0));
          const pick:any=ranked[0];
          scoutProfileId=Number(pick?.profile_id||0);
          scoutName=String(pick?.p?.name||pick?.name||"Recruteur");
          scoutRating=Number(pick?.p?.scouting_rating||10);
        }
      }

      const eta=new Date(today+"T12:00:00Z");
      eta.setUTCDate(eta.getUTCDate()+Math.max(21,Math.min(70,Math.round((11-scoutRating*.32)*7))));
      const assignmentPatch:any={
        focus,progress:0,status:"active",started_at:today,last_update:today,
        staff_profile_id:scoutProfileId||null,
        scout_name:scoutName||"Réseau scouting",
        confidence:Math.max(45,Math.min(95,48+scoutRating*2)),
        report_quality:Math.max(40,Math.min(96,45+scoutRating*2)),
        eta_date:eta.toISOString().slice(0,10)
      };
      if(region)assignmentPatch.region=region;
      const up=await db.from("scouting_assignments").update(assignmentPatch).eq("id",id);
      if(up.error)return h({error:up.error.message},500);
      await db.from("scouting_reports").delete().eq("assignment_id",id);
      await db.from("inbox_items").insert({
        kind:"scouting",title:"Nouvelle mission scouting",
        body:"Mission lancée : "+focus+" · "+(scoutName||"réseau scouting")+" affecté.",
        action_route:"scouting",is_read:false
      });
      return h({ok:true,focus,region:region||null,scout_profile_id:scoutProfileId||null,scout_name:scoutName,eta_date:eta.toISOString().slice(0,10)});
    }


    if(action==="recruit_scouted_player"){
      const reportId=Number(body?.report_id||0);
      const report=await db.from("scouting_reports")
        .select("*").eq("id",reportId).eq("player_id",id).maybeSingle();
      if(report.error||!report.data)return h({error:report.error?.message||"Rapport scouting introuvable."},404);
      if(Number(report.data.confidence||0)<60)return h({error:"Connaissance insuffisante : atteins au moins 60% de confiance avant une approche."},409);

      const player=await db.from("players")
        .select("id,name,country,ranking,junior_ranking,birth_date,age,current_ability,potential,ncaa_current,career_status")
        .eq("id",id).maybeSingle();
      if(player.error||!player.data)return h({error:player.error?.message||"Joueur introuvable."},404);
      const p:any=player.data;
      const playerAge=ageAt(p.birth_date,String(career.data.career_date||AGE_REFERENCE_DATE),p.age);
      if(playerAge>21)return h({error:"Le recrutement académie depuis le scouting est réservé aux joueurs de 21 ans ou moins."},409);
      if(Boolean(p.ncaa_current))return h({error:"Ce joueur est actuellement NCAA. Utilise la filière universitaire plutôt qu’un contrat académie pro."},409);
      if(String(p.career_status||"active")!=="active")return h({error:"Ce joueur n’est pas disponible pour un recrutement actif."},409);
      if(Number(p.id)===Number(career.data.managed_player_id||0))return h({error:"Le joueur principal fait déjà partie de ta structure."},409);

      const existing=await db.from("academy_roster").select("*").eq("player_id",id).maybeSingle();
      if(existing.error)return h({error:existing.error.message},500);
      if(existing.data&&existing.data.status==="active")return h({ok:true,already:true,roster:existing.data,budget:Number(career.data.budget||0)});

      const academy=await db.from("academies").select("youth_capacity,academy_level,reputation").eq("id","demo").maybeSingle();
      if(academy.error)return h({error:academy.error.message},500);
      const activeRoster=await db.from("academy_roster").select("id",{count:"exact",head:true}).eq("status","active");
      if(activeRoster.error)return h({error:activeRoster.error.message},500);
      const capacity=Math.max(4,Number(academy.data?.youth_capacity||8));
      if(Number(activeRoster.count||0)>=capacity)return h({error:"Capacité académie atteinte. Agrandis la structure ou libère une place."},409);

      const estPa=Math.round((Number(report.data.estimated_pa_min||p.potential||60)+Number(report.data.estimated_pa_max||p.potential||60))/2);
      const estCa=Math.round((Number(report.data.estimated_ca_min||p.current_ability||45)+Number(report.data.estimated_ca_max||p.current_ability||45))/2);
      const rank=Number(p.ranking||3000);
      const signingCost=Math.max(500,Math.round(estPa*70+Math.max(0,1800-rank)*1.4));
      const weeklyCost=Math.max(100,Math.round(estCa*5+Math.max(0,1200-rank)*.22));
      let budget=Number(career.data.budget||0);
      if(budget<signingCost)return h({error:"Budget insuffisant pour l’approche : "+signingCost+" € requis.",signing_cost:signingCost},409);
      budget-=signingCost;

      const start=String(career.data.career_date||AGE_REFERENCE_DATE);
      const end=new Date(start+"T12:00:00Z");end.setUTCFullYear(end.getUTCFullYear()+2);
      const endDate=end.toISOString().slice(0,10);
      const rosterPayload={
        player_id:id,source_youth_id:null,contract_start:start,contract_end:endDate,
        weekly_cost:weeklyCost,squad_role:"Prospect scouté",development_focus:"Équilibré",status:"active"
      };
      const roster=existing.data
        ?await db.from("academy_roster").update(rosterPayload).eq("id",existing.data.id).select("*").single()
        :await db.from("academy_roster").insert(rosterPayload).select("*").single();
      if(roster.error)return h({error:roster.error.message},500);

      const budgetUpdate=await db.from("career_state").update({budget,updated_at:new Date().toISOString()}).eq("id","demo");
      if(budgetUpdate.error)return h({error:budgetUpdate.error.message},500);
      await db.from("contracts").insert({
        subject_type:"player",subject_name:p.name,role:"Prospect scouté",
        weekly_salary:weeklyCost,start_date:start,end_date:endDate,
        bonuses:{signing_fee:signingCost,source:"scouting_report",report_id:reportId},status:"active"
      });
      await db.from("inbox_items").insert({
        kind:"academy",title:"Recrutement académie · "+p.name,
        body:p.name+" rejoint l’académie pour 2 ans. Prime "+signingCost+" € · "+weeklyCost+" €/sem.",
        action_route:"academy",is_read:false,game_date:start,priority:"normal",
        action_type:"open_route",action_label:"Voir l’académie",action_payload:{route:"academy"},
        decision_status:"info",related_entity_type:"academy_player",related_entity_id:id
      });
      await db.from("career_event_log").insert({
        event_date:start,week:Number(career.data.week||1),system:"academy",event_type:"scouted_recruitment",
        summary:"Recrutement de "+p.name,
        payload:{player_id:id,report_id:reportId,signing_cost:signingCost,weekly_cost:weeklyCost,contract_end:endDate}
      });
      return h({ok:true,player_id:id,player_name:p.name,signing_cost:signingCost,weekly_cost:weeklyCost,contract_end:endDate,budget,roster:roster.data});
    }


    if(action==="request_wildcard"){
      const primaryId=Number(career.data.managed_player_id||0);
      const playerId=n(body?.player_id,primaryId,1,99999999);
      let focus=String(career.data.career_focus||"mixed");
      let rank=Number(career.data.singles_rank||9999);
      let playerName=String(career.data.player_name||"Joueur");
      if(playerId!==primaryId){
        const [roster,player]=await Promise.all([
          db.from("academy_roster").select("id").eq("player_id",playerId).eq("status","active").maybeSingle(),
          db.from("players").select("id,name,ranking,career_focus").eq("id",playerId).maybeSingle()
        ]);
        if(roster.error||player.error)return h({error:(roster.error||player.error)?.message},500);
        if(!roster.data||!player.data)return h({error:"Ce joueur ne fait pas partie du groupe géré."},403);
        focus=String(player.data.career_focus||"mixed");
        rank=Number(player.data.ranking||9999);
        playerName=String(player.data.name||"Joueur");
      }
      if(focus==="doubles_only"){
        return h({error:"Carrière en mode Double exclusivement : les wild cards simple sont désactivées."},409);
      }
      const [t,a]=await Promise.all([
        db.from("tournaments").select("*").eq("id",id).maybeSingle(),
        db.from("academies").select("reputation").eq("id","demo").maybeSingle()
      ]);
      if(t.error||a.error||!t.data)return h({error:(t.error||a.error)?.message||"Tournoi introuvable"},404);
      if(["ATP","Challenger","ITF"].includes(String(t.data.circuit))){
        const eligibility=await db.rpc("player_event_eligibility",{p_player_id:playerId,p_tournament_id:id,p_entry_method:"wildcard"});
        if(eligibility.error)return h({error:eligibility.error.message},500);
        if(eligibility.data?.eligible===false)return h({error:"Wild card impossible : le règlement de ce circuit interdit l'entrée de ce joueur.",entry_rule:eligibility.data},409);
      }
      const qual=Number(t.data.qual_cut??t.data.projected_qual_cut??t.data.direct_cut??t.data.projected_direct_cut??rank);
      const rep=Number(a.data?.reputation||48);
      const proximity=Math.max(0,35-Math.max(0,rank-qual)/12);
      const score=Math.round(rep*.65+proximity+Math.random()*22);
      const status=score>=58?"accepted":"declined";
      const up=await db.from("wildcard_requests").upsert({
        tournament_id:id,player_id:playerId,status,decision_score:score,created_at:new Date().toISOString()
      },{onConflict:"tournament_id,player_id"}).select("*").single();
      if(up.error)return h({error:up.error.message},500);
      await db.from("inbox_items").insert({
        kind:"tournament",title:"Décision wild card · "+playerName,
        body:(status==="accepted"?"Wild card accordée pour ":"Wild card refusée pour ")+t.data.name+".",
        action_route:"calendar",is_read:false,related_entity_type:"player",related_entity_id:playerId
      });
      return h({ok:true,status,score,player_id:playerId});
    }


    if(action==="set_career_focus"){
      const focus=String(body?.focus||"").trim().toLowerCase();
      if(!["singles_only","singles_priority","mixed","doubles_only"].includes(focus))return h({error:"Orientation de carrière invalide"},400);

      const primaryId=Number(career.data.managed_player_id||0);
      const playerId=n(body?.player_id,primaryId,1,99999999);
      const isPrimary=playerId===primaryId;
      let playerName=String(career.data.player_name||"Joueur");
      let playerCountry=String(career.data.country||"FRA").toUpperCase();

      if(!isPrimary){
        const [roster,player]=await Promise.all([
          db.from("academy_roster").select("id").eq("player_id",playerId).eq("status","active").maybeSingle(),
          db.from("players").select("id,name,country,career_focus").eq("id",playerId).maybeSingle()
        ]);
        if(roster.error||player.error)return h({error:(roster.error||player.error)?.message},500);
        if(!roster.data||!player.data)return h({error:"Ce joueur ne fait pas partie du groupe géré."},403);
        playerName=String(player.data.name||"Joueur");
        playerCountry=String(player.data.country||"FRA").toUpperCase();
      }

      const focusDate=String(career.data.career_date||AGE_REFERENCE_DATE);
      const result=isPrimary
        ?await db.rpc("set_managed_career_focus",{p_focus:focus,p_date:focusDate})
        :await db.rpc("set_player_career_focus",{p_player_id:playerId,p_focus:focus,p_date:focusDate});
      if(result.error)return h({error:result.error.message},500);

      const labels:any={singles_only:"Simple exclusivement",singles_priority:"Simple prioritaire",mixed:"Simple + double",doubles_only:"Double exclusivement"};
      let needsPartner=false;
      let davisRole:any=null;

      if(focus==="doubles_only"){
        const activeSingles=await db.from("entries")
          .select("tournament_id")
          .eq("player_id",playerId).eq("status","entered");
        if(activeSingles.error)return h({error:activeSingles.error.message},500);
        const activeTournamentIds=[...new Set((activeSingles.data??[]).map((x:any)=>Number(x.tournament_id)).filter(Boolean))];

        const wd=await db.from("entries").update({
          status:"withdrawn",withdrawn_on:focusDate,updated_at:new Date().toISOString()
        }).eq("player_id",playerId).eq("status","entered");
        if(wd.error)return h({error:wd.error.message},500);

        for(const tournamentId of activeTournamentIds){
          const tr=await db.from("tournaments")
            .select("qualifying_start_date,main_draw_start_date,start_date")
            .eq("id",tournamentId).maybeSingle();
          const qStart=String(tr.data?.qualifying_start_date||tr.data?.main_draw_start_date||tr.data?.start_date||focusDate);
          const phase=focusDate<qStart?"pre_q":"post_q";

          await db.from("world_tournament_acceptance_entries").update({
            status:"withdrawn",withdrawn_on:focusDate,withdrawal_phase:phase,
            withdrawal_reason:"career_focus_doubles_only",updated_at:new Date().toISOString()
          }).eq("tournament_id",tournamentId).eq("player_id",playerId)
            .in("status",["accepted","promoted","alternate"]);

          await db.from("world_qualifying_acceptance_entries").update({
            status:"withdrawn",withdrawn_on:focusDate,withdrawal_phase:"pre_q",
            withdrawal_reason:"career_focus_doubles_only",updated_at:new Date().toISOString()
          }).eq("tournament_id",tournamentId).eq("player_id",playerId)
            .in("status",["accepted","promoted","alternate"]);

          await db.rpc("refresh_world_tournament_acceptance_list",{p_tournament_id:tournamentId,p_date:focusDate});
          await db.rpc("refresh_world_qualifying_acceptance_list",{p_tournament_id:tournamentId,p_date:focusDate});
        }

        const pair=await db.from("doubles_partnerships")
          .select("id,player_a_id,player_b_id")
          .or("player_a_id.eq."+playerId+",player_b_id.eq."+playerId)
          .order("id",{ascending:false}).limit(1).maybeSingle();
        if(pair.error)return h({error:pair.error.message},500);
        const partnerId=pair.data
          ?(Number(pair.data.player_a_id)===playerId?Number(pair.data.player_b_id):Number(pair.data.player_a_id))
          :0;
        needsPartner=!partnerId;

        if(partnerId){
          const syncMetric=await db.rpc("doubles_pair_metrics",{p_a:playerId,p_b:partnerId,p_date:focusDate});
          if(!syncMetric.error){
            const mm:any=(syncMetric.data??[])[0]||{};
            await db.from("player_doubles_commitments").upsert({
              player_id:playerId,
              season:Number(focusDate.slice(0,4)),
              primary_partner_id:partnerId,
              started_at:focusDate,
              last_review_date:focusDate,
              commitment:Math.max(65,Math.min(100,Math.round(Number(mm.affinity_score||70))+6)),
              affinity:Math.max(0,Math.min(100,Number(mm.chemistry||70))),
              reason:"Partenaire principal confirmé lors du passage en Double exclusivement.",
              source_label:"Utilisateur · groupe géré · carrière double exclusivement",
              active:true,updated_at:new Date().toISOString()
            },{onConflict:"player_id"});
          }
        }

        const nation=(isPrimary?String(career.data.selected_federation_nation||career.data.federation_nation||playerCountry):playerCountry).toUpperCase();
        const ownDavis=await db.from("davis_squad").select("id,role").eq("player_id",playerId).eq("nation",nation).maybeSingle();
        if(!ownDavis.error&&ownDavis.data&&/^Simple/i.test(String(ownDavis.data.role||""))){
          const taken=await db.from("davis_squad").select("role,player_id").eq("nation",nation).in("role",["Double A","Double B"]);
          const used=new Set((taken.data??[]).filter((x:any)=>Number(x.player_id)!==playerId).map((x:any)=>String(x.role)));
          davisRole=!used.has("Double A")?"Double A":!used.has("Double B")?"Double B":"Réserve";
          await db.from("davis_squad").update({role:davisRole}).eq("id",ownDavis.data.id);
        }
      }else if(focus==="singles_only"){
        const doublesWd=await db.from("managed_doubles_entries").update({
          status:"withdrawn",withdrawn_on:focusDate,
          metadata:{withdrawal_reason:"career_focus_singles_only"},
          updated_at:new Date().toISOString()
        }).eq("owner_id","demo").eq("player_id",playerId).eq("status","entered");
        if(doublesWd.error)return h({error:doublesWd.error.message},500);

        const nation=(isPrimary?String(career.data.selected_federation_nation||career.data.federation_nation||playerCountry):playerCountry).toUpperCase();
        const ownDavis=await db.from("davis_squad").select("id,role").eq("player_id",playerId).eq("nation",nation).maybeSingle();
        if(!ownDavis.error&&ownDavis.data&&/^Double/i.test(String(ownDavis.data.role||""))){
          const taken=await db.from("davis_squad").select("role,player_id").eq("nation",nation).in("role",["Simple 1","Simple 2"]);
          const used=new Set((taken.data??[]).filter((x:any)=>Number(x.player_id)!==playerId).map((x:any)=>String(x.role)));
          davisRole=!used.has("Simple 1")?"Simple 1":!used.has("Simple 2")?"Simple 2":"Réserve";
          await db.from("davis_squad").update({role:davisRole}).eq("id",ownDavis.data.id);
        }
      }

      await db.from("inbox_items").insert({
        kind:"career",title:"Orientation de carrière · "+playerName,
        body:"Nouvelle orientation : "+labels[focus]+(needsPartner?" · choisis maintenant un partenaire dans le hub Double.":"."),
        action_route:needsPartner?"doubles":"myplayer",is_read:false,
        related_entity_type:"player",related_entity_id:playerId
      });
      const [boardRefresh,sponsorRefresh]=await Promise.all([
        db.rpc("update_board_state"),
        db.rpc("refresh_sponsor_offer_eligibility",{p_date:focusDate})
      ]);
      return h({
        ok:true,...(result.data||{}),player_id:playerId,player_name:playerName,
        label:labels[focus],needs_partner:needsPartner,davis_role:davisRole,
        board:boardRefresh.error?{error:boardRefresh.error.message}:boardRefresh.data,
        sponsor_visibility:sponsorRefresh.error?{error:sponsorRefresh.error.message}:sponsorRefresh.data
      });
    }


    if(action==="edit_career"){
      const field=String(body?.field||"");
      const allowed=["player_name","country","style","age","height_cm","weight_kg"];
      if(!allowed.includes(field))return h({error:"Champ non modifiable"},400);

      const primaryId=Number(career.data.managed_player_id||0);
      const playerId=n(body?.player_id,primaryId,1,99999999);
      if(!playerId)return h({error:"Joueur géré introuvable"},409);
      const isPrimary=playerId===primaryId;

      if(!isPrimary){
        const roster=await db.from("academy_roster")
          .select("id").eq("player_id",playerId).eq("status","active").maybeSingle();
        if(roster.error)return h({error:roster.error.message},500);
        if(!roster.data)return h({error:"Ce joueur ne fait pas partie du groupe géré."},403);
      }

      let value:any=body?.value;
      if(["age","height_cm","weight_kg"].includes(field))value=n(value,0,1,250);
      else value=String(value??"").trim().slice(0,80);

      const pu:any={};
      if(field==="player_name")pu.name=value;
      if(field==="country")pu.country=value;
      if(field==="style")pu.style=value;
      if(field==="age")pu.age=value;
      if(field==="height_cm")pu.height_cm=value;
      if(field==="weight_kg")pu.weight_kg=value;

      if(Object.keys(pu).length){
        const p=await db.from("players").update(pu).eq("id",playerId).select("id,name,country,style,age,height_cm,weight_kg").maybeSingle();
        if(p.error)return h({error:p.error.message},500);
      }

      if(isPrimary){
        const up:any={updated_at:new Date().toISOString()};up[field]=value;
        const cu=await db.from("career_state").update(up).eq("id","demo");
        if(cu.error)return h({error:cu.error.message},500);
      }

      return h({ok:true,field,value,player_id:playerId,is_primary_managed:isPrimary});
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
      await recordFinanceTransactions([{
        transaction_key:"facility:"+id+":level:"+(level+1),game_date:String(career.data.career_date||AGE_REFERENCE_DATE),week:Number(career.data.week||1),
        category:"facility_upgrade",amount:-cost,source_type:"facility",source_id:id,
        description:"Amélioration installation · "+String(fac.data.name||"Installation")+" niveau "+(level+1),balance_after:budget
      }]);
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
      const startDate=String(body?.date||AGE_REFERENCE_DATE).slice(0,10);
      const [target,previousCareer,baseline,rankAtDate,doublePointsBaseline,doubleRankAtDate,principalRoster,principalMember]=await Promise.all([
        db.from("players").select("*,player_attributes(*)").eq("id",id).maybeSingle(),
        db.from("career_state").select("managed_player_id").eq("id","demo").maybeSingle(),
        db.from("atp_ranking_baseline_2025_12_01").select("rank,points,snapshot_date,source_label").eq("source_player_id",id).maybeSingle(),
        db.rpc("player_rank_at_date",{p_player_id:id,p_date:startDate}),
        db.from("doubles_baseline_points").select("points,snapshot_date,source_label").eq("player_id",id).eq("snapshot_date",AGE_REFERENCE_DATE).maybeSingle(),
        db.rpc("player_doubles_seed_rank_at_date",{p_player_id:id,p_date:startDate}),
        db.from("academy_roster").select("id,player_id,squad_role,status,players(name)").eq("squad_role","Joueur principal").eq("status","active").limit(1).maybeSingle(),
        db.from("academy_members").select("id,player_id,display_name,member_type,status").eq("member_type","managed").eq("status","active").limit(1).maybeSingle()
      ]);
      if(target.error||previousCareer.error||baseline.error||rankAtDate.error||doublePointsBaseline.error||doubleRankAtDate.error||principalRoster.error||principalMember.error||!target.data){
        return h({error:(target.error||previousCareer.error||baseline.error||rankAtDate.error||doublePointsBaseline.error||doubleRankAtDate.error||principalRoster.error||principalMember.error)?.message||"Joueur introuvable"},404);
      }
      const p:any=target.data;
      const extraIds=[...new Set((Array.isArray(body?.additional_player_ids)?body.additional_player_ids:[])
        .map((x:any)=>Number(x)).filter((x:number)=>Number.isFinite(x)&&x>0&&x!==Number(p.id)).slice(0,7))];
      let extraPlayers:any[]=[];
      if(extraIds.length){
        const extraRows=await db.from("players")
          .select("id,name,country,ranking,points,doubles_ranking,doubles_points,itf_ranking,current_ability,potential,career_status")
          .in("id",extraIds);
        if(extraRows.error)return h({error:extraRows.error.message},500);
        extraPlayers=extraRows.data??[];
        if(extraPlayers.length!==extraIds.length)return h({error:"Un des joueurs sélectionnés est introuvable."},404);
        if(extraPlayers.some((x:any)=>String(x.career_status||"active")==="retired"))return h({error:"Un joueur retraité ne peut pas rejoindre l'académie de départ."},409);
      }
      const academyInput=body?.academy&&typeof body.academy==="object"?body.academy:{};
      const academyLevel=n(academyInput?.level,2,1,4);
      const academyCapacity=({1:2,2:4,3:6,4:8} as any)[academyLevel]||4;
      if(1+extraPlayers.length>academyCapacity)return h({error:"Cette académie accepte au maximum "+academyCapacity+" joueurs au départ."},409);
      const difficultyKey=["discovery","normal","manager","hardcore"].includes(String(body?.difficulty||"normal"))?String(body?.difficulty||"normal"):"normal";
      const managerProfile=body?.manager_profile&&typeof body.manager_profile==="object"?body.manager_profile:{};
      const attrs:any=Array.isArray(p.player_attributes)?p.player_attributes[0]:p.player_attributes||{};
      const previousId=Number(previousCareer.data?.managed_player_id||0);
      const managedIds=[...new Set([
        previousId,Number(p.id),...(extraPlayers||[]).map((x:any)=>Number(x.id||0))
      ].filter(Boolean))];
      const scoutingEtaDate=(()=>{const d=new Date(startDate+"T12:00:00Z");d.setUTCDate(d.getUTCDate()+28);return d.toISOString().slice(0,10)})();
      const academyContractEnd=(()=>{const d=new Date(startDate+"T12:00:00Z");d.setUTCFullYear(d.getUTCFullYear()+3);return d.toISOString().slice(0,10)})();
      const startingRank=Math.max(1,Number(baseline.data?.rank||rankAtDate.data||p.ranking||2000));
      const basePoints=Math.max(0,Number(baseline.data?.points??p.points??0));
      const startingFocus=String(p.career_focus||"mixed");
      const historicalDoubleRank=Number(doubleRankAtDate.data||0);
      const baseDoubleRank=historicalDoubleRank>0&&historicalDoubleRank<999999
        ?historicalDoubleRank
        :(p.doubles_ranking==null?3000:Math.max(1,Number(p.doubles_ranking)));
      const baseDoublePoints=Math.max(0,Number(
        doublePointsBaseline.data?.points
        ??(p.doubles_ranking==null?0:Math.round(45*(1800/baseDoubleRank-1)))
      ));
      const principalPlayers:any=(principalRoster.data as any)?.players;
      const previousPrincipalName=String(
        (Array.isArray(principalPlayers)?principalPlayers[0]?.name:principalPlayers?.name)
        ||principalMember.data?.display_name||""
      ).trim();

      const currentTournamentRuns=await db.from("tournament_runs").select("id");
      if(currentTournamentRuns.error)return h({error:"Reset carrière impossible : "+currentTournamentRuns.error.message},500);
      const tournamentRunIds=(currentTournamentRuns.data??[]).map((x:any)=>Number(x.id)).filter(Boolean);
      if(tournamentRunIds.length){
        const drawDelete=await db.from("tournament_draw_matches").delete().in("run_id",tournamentRunIds);
        if(drawDelete.error)return h({error:"Reset carrière impossible : "+drawDelete.error.message},500);
      }
      const currentDoublesRuns=await db.from("doubles_runs").select("id");
      if(currentDoublesRuns.error)return h({error:"Reset carrière impossible : "+currentDoublesRuns.error.message},500);
      const doublesRunIds=(currentDoublesRuns.data??[]).map((x:any)=>Number(x.id)).filter(Boolean);
      if(doublesRunIds.length){
        const doublesHistoryDelete=await db.from("doubles_match_history").delete().in("run_id",doublesRunIds);
        if(doublesHistoryDelete.error)return h({error:"Reset carrière impossible : "+doublesHistoryDelete.error.message},500);
      }
      const resetOps:any[]=[
        db.from("tournament_runs").delete().gte("id",0),
        db.from("doubles_runs").delete().gte("id",0),
        db.from("match_history").delete().eq("user_involved",true),
        db.from("wildcard_requests").delete().gte("id",0),
        db.from("shortlist").delete().gte("player_id",0),
        db.from("scouting_reports").delete().gte("id",0),
        db.from("scouting_assignments").update({
          progress:0,status:"active",confidence:45,report_quality:40,
          started_at:startDate,last_update:startDate,eta_date:scoutingEtaDate
        }).gte("id",0),
        db.from("user_ranking_points").delete().eq("owner_id","demo"),
        db.from("user_doubles_points").delete().eq("owner_id","demo"),
        db.from("user_training_progress").update({xp:0,updated_at:new Date().toISOString()}).neq("attribute",""),
        db.from("managed_doubles_entries").delete().eq("owner_id","demo"),
        db.from("inbox_items").delete().gte("id",0),
        db.from("finance_transactions").delete().gte("id",0),
        db.from("media_events").delete().gte("id",0),
        db.from("career_event_log").delete().gte("id",0),
        db.from("college_offers").update({status:"available"}).gte("id",0),
        db.from("college_career_state").update({
          chosen_team_id:null,scholarship_pct:0,eligibility_years:4,status:"exploring",
          academic_progress:72,coach_trust:55,lineup_position:null
        }).eq("id","demo"),
        db.from("sponsor_offers").update({status:"available"}).neq("status","locked"),
        db.from("board_objectives").update({progress:0,status:"active"}).gte("id",0),
        db.from("medical_plan").upsert({
          id:"demo",protocol:"Récupération active",physio_hours:2,weekly_cost:250,
          notes:"Récupération active et suivi médical",updated_at:new Date().toISOString()
        },{onConflict:"id"}),
        db.from("academy_youth").update({status:"prospect"}).neq("status","prospect"),
        db.from("academy_roster").delete().neq("squad_role","Joueur principal"),
        db.from("academy_members").delete().neq("member_type","managed")
      ];
      if(managedIds.length){
        resetOps.push(
          db.from("entries").delete().in("player_id",managedIds),
          db.from("doubles_partner_offers").delete().in("from_player_id",managedIds),
          db.from("doubles_partner_offers").delete().in("to_player_id",managedIds),
          db.from("player_doubles_commitments").delete().in("player_id",managedIds),
          db.from("managed_player_training_progress").delete().in("player_id",managedIds),
          db.from("injuries").delete().in("player_id",managedIds).gte("started_at",startDate)
        );
      }
      const resetResults=await Promise.all(resetOps);
      const resetError=resetResults.find((x:any)=>x?.error)?.error;
      if(resetError)return h({error:"Reset carrière impossible : "+resetError.message},500);

      const baselineExpiry=(()=>{const d=new Date(startDate+"T12:00:00Z");d.setUTCDate(d.getUTCDate()+364);return d.toISOString().slice(0,10)})();
      await db.from("user_ranking_points").insert({
        owner_id:"demo",player_id:Number(p.id),label:"Points de départ - "+p.name,earned_date:startDate,
        expiry_date:baselineExpiry,points:basePoints,active:true
      });
      for(const ep of extraPlayers){
        const epPoints=Math.max(0,Number(ep.points||0));
        const epBaseline=await db.from("user_ranking_points").insert({
          owner_id:"demo",player_id:Number(ep.id),label:"Points de départ - "+String(ep.name),
          earned_date:startDate,expiry_date:baselineExpiry,points:epPoints,active:true
        });
        if(epBaseline.error)return h({error:"Baseline ATP impossible pour "+String(ep.name)+": "+epBaseline.error.message},500);
      }
      await db.from("user_doubles_points").insert({
        owner_id:"demo",player_id:Number(p.id),label:"Points double de départ - "+p.name,earned_date:startDate,
        expiry_date:(()=>{const d=new Date(startDate+"T12:00:00Z");d.setUTCDate(d.getUTCDate()+364);return d.toISOString().slice(0,10)})(),
        points:baseDoublePoints,active:true,partner_id:null
      });

      const careerUpdate={
        managed_player_id:p.id,
        player_name:p.name,country:p.country,career_date:startDate,week:1,
        singles_rank:startingRank,doubles_rank:baseDoubleRank,points:basePoints,doubles_points:baseDoublePoints,
        age:Number(p.age||19),height_cm:Number(p.height_cm||184),weight_kg:Number(p.weight_kg||78),
        handedness:String(p.handedness||"Droitier"),backhand:String(p.backhand||"2 mains"),
        current_ability:Number(p.current_ability||55),potential:Number(p.potential||75),
        form:Number(p.form||70),fitness:Number(p.fitness||90),morale:Number(p.morale||75),fatigue:Number(p.fatigue||15),
        budget:14800,style:String(p.style||"All-court"),injury_status:"Fit",
        career_focus:startingFocus,
        career_focus_changed_at:startDate,
        career_focus_switches:0,
        career_focus_reason:String(p.career_focus_reason||"Orientation de départ issue du profil du joueur."),
        updated_at:new Date().toISOString()
      };
      const cu=await db.from("career_state").update(careerUpdate).eq("id","demo");
      if(cu.error)return h({error:cu.error.message},500);

      if(principalRoster.data?.id){
        const ar=await db.from("academy_roster").update({
          player_id:p.id,source_youth_id:null,contract_start:startDate,contract_end:academyContractEnd,
          weekly_cost:0,squad_role:"Joueur principal",development_focus:"Équilibré",status:"active"
        }).eq("id",principalRoster.data.id);
        if(ar.error)return h({error:ar.error.message},500);
      }else{
        const ar=await db.from("academy_roster").insert({
          player_id:p.id,source_youth_id:null,contract_start:startDate,contract_end:academyContractEnd,
          weekly_cost:0,squad_role:"Joueur principal",development_focus:"Équilibré",status:"active"
        });
        if(ar.error)return h({error:ar.error.message},500);
      }
      if(principalMember.data?.id){
        const am=await db.from("academy_members").update({
          player_id:p.id,youth_id:null,display_name:p.name,country:p.country,role:"Joueur principal",
          development_focus:"Équilibré",weekly_cost:0,contract_end:academyContractEnd,status:"active",joined_at:startDate
        }).eq("id",principalMember.data.id);
        if(am.error)return h({error:am.error.message},500);
      }else{
        const am=await db.from("academy_members").insert({
          member_type:"managed",player_id:p.id,youth_id:null,display_name:p.name,country:p.country,
          role:"Joueur principal",development_focus:"Équilibré",weekly_cost:0,
          contract_end:academyContractEnd,status:"active",joined_at:startDate
        });
        if(am.error)return h({error:am.error.message},500);
      }

      const academyName=String(academyInput?.name||"Court Boss Academy").trim().slice(0,80)||"Court Boss Academy";
      const academyCountry=String(academyInput?.country||p.country||"FRA").trim().toUpperCase().slice(0,3)||"FRA";
      const academyReputation=n(academyInput?.reputation,academyLevel===4?80:academyLevel===3?66:academyLevel===2?50:34,20,95);
      const academyBudget=Math.max(5000,Math.min(200000,Number(academyInput?.budget||({1:9000,2:15000,3:26000,4:45000} as any)[academyLevel])));
      const academyReach=n(academyInput?.recruitment_reach,academyLevel,1,5);
      const academyIntensity=n(academyInput?.development_intensity,academyLevel,1,5);
      const academyUpdate=await db.from("academies").update({
        name:academyName,country:academyCountry,academy_level:academyLevel,
        reputation:academyReputation,budget:academyBudget,
        recruitment_reach:academyReach,development_intensity:academyIntensity
      }).eq("id","demo");
      if(academyUpdate.error)return h({error:academyUpdate.error.message},500);

      for(let i=0;i<extraPlayers.length;i++){
        const ep:any=extraPlayers[i];
        const role="Joueur académie";
        const rr=await db.from("academy_roster").insert({
          player_id:Number(ep.id),source_youth_id:null,contract_start:startDate,contract_end:academyContractEnd,
          weekly_cost:0,squad_role:role,development_focus:"Équilibré",status:"active"
        });
        if(rr.error)return h({error:"Ajout académie impossible pour "+String(ep.name)+": "+rr.error.message},500);
        const mm=await db.from("academy_members").insert({
          member_type:"player",player_id:Number(ep.id),youth_id:null,display_name:String(ep.name),
          country:String(ep.country||"FRA"),role,development_focus:"Équilibré",weekly_cost:0,
          contract_end:academyContractEnd,status:"active",joined_at:startDate
        });
        if(mm.error)return h({error:"Ajout membre impossible pour "+String(ep.name)+": "+mm.error.message},500);
        const ec=await db.from("contracts").insert({
          subject_type:"player",subject_name:String(ep.name),role:"Joueur académie",
          weekly_salary:0,start_date:startDate,end_date:academyContractEnd,
          bonuses:{source:"new_career_managed_squad",player_id:Number(ep.id)},status:"active"
        });
        if(ec.error)return h({error:"Contrat académie impossible pour "+String(ep.name)+": "+ec.error.message},500);
      }

      const principalContract=previousPrincipalName
        ?await db.from("contracts").select("id").eq("subject_type","player").eq("subject_name",previousPrincipalName).eq("status","active").limit(1).maybeSingle()
        :await db.from("contracts").select("id").eq("subject_type","player").eq("role","Joueur").eq("status","active").eq("weekly_salary",0).limit(1).maybeSingle();
      if(principalContract.error)return h({error:principalContract.error.message},500);
      if(principalContract.data?.id){
        const pc=await db.from("contracts").update({
          subject_name:p.name,role:"Joueur principal",start_date:startDate,end_date:academyContractEnd,
          status:"active",weekly_salary:0,bonuses:{source:"new_career_managed_squad",player_id:Number(p.id)}
        }).eq("id",principalContract.data.id);
        if(pc.error)return h({error:pc.error.message},500);
      }else{
        const pc=await db.from("contracts").insert({
          subject_type:"player",subject_name:String(p.name),role:"Joueur principal",
          weekly_salary:0,start_date:startDate,end_date:academyContractEnd,
          bonuses:{source:"new_career_managed_squad",player_id:Number(p.id)},status:"active"
        });
        if(pc.error)return h({error:"Contrat du joueur principal impossible : "+pc.error.message},500);
      }

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

      await db.from("finances").update({
        prize_money:0,sponsor_income:0,travel_cost:0,staff_cost:0,agent_commission:0,staff_bonus:0,base_currency:BASE_CURRENCY
      }).eq("id","demo");
      await recordFinanceTransactions([{
        transaction_key:"opening:"+startDate,game_date:startDate,week:1,category:"opening",amount:14800,
        source_type:"career",source_id:Number(p.id),description:"Solde d’ouverture · nouvelle carrière avec "+String(p.name),
        balance_after:14800,metadata:{model:"CB-FINANCE-LEDGER-v1",managed_player_id:Number(p.id)}
      }]);
      await db.rpc("refresh_sponsor_offer_eligibility",{p_date:startDate});
      await Promise.all([
        db.from("news_items").insert({body:"Nouvelle carrière lancée avec "+p.name+"."}),
        db.from("inbox_items").insert([
          {
            kind:"career",title:"Bienvenue, "+String(managerProfile?.name||"manager"),
            body:"Tu prends en main "+p.name+" au "+startDate+" en difficulté "+difficultyKey+". Ton académie compte "+String(1+extraPlayers.length)+" joueur(s).",
            action_route:"careerhub",game_date:startDate,priority:"high",action_type:"open_route",action_label:"Ouvrir le Bureau manager",
            action_payload:{route:"careerhub"},decision_status:"info",is_read:false
          },
          {
            kind:"academy",title:"Effectif de départ confirmé",
            body:academyName+" ouvre la saison avec "+[p,...extraPlayers].map((x:any)=>String(x.name)).join(", ")+".",
            action_route:"academy",game_date:startDate,priority:"normal",action_type:"open_route",action_label:"Voir l'académie",
            action_payload:{route:"academy"},decision_status:"info",is_read:false
          },
          {
            kind:"training",title:"Prépare les plans d'entraînement",
            body:"Chaque joueur de l'académie peut recevoir son propre plan hebdomadaire. La dominante du plan influence son développement.",
            action_route:"training",game_date:startDate,priority:"high",action_type:"open_route",action_label:"Planifier l'entraînement",
            action_payload:{route:"training"},decision_status:"info",is_read:false
          }
        ])
      ]);
      return h({
        ok:true,
        player:{id:p.id,name:p.name,country:p.country,ranking:startingRank,doubles_ranking:baseDoubleRank},
        career:careerUpdate,
        baseline:{
          date:startDate,singles_rank:startingRank,singles_points:basePoints,
          doubles_rank:baseDoubleRank,doubles_points:baseDoublePoints,
          singles_source:baseline.data?.source_label||"player_rank_at_date / profile fallback",
          doubles_source:doublePointsBaseline.data?.source_label||"doubles rank-calibrated fallback"
        }
      });
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

      const primaryId=Number(career.data.managed_player_id||0);
      let injury:any=null;
      if(id>0){
        const injuryRes=await db.from("injuries").select("id,player_id,injury_type,status").eq("id",id).maybeSingle();
        if(injuryRes.error)return h({error:injuryRes.error.message},500);
        injury=injuryRes.data;
        if(!injury)return h({error:"Blessure introuvable"},404);
      }
      const managedId=Number(injury?.player_id||body?.player_id||primaryId||0);
      if(!managedId)return h({error:"Joueur géré introuvable"},409);
      if(managedId!==primaryId){
        const roster=await db.from("academy_roster").select("id").eq("player_id",managedId).eq("status","active").maybeSingle();
        if(roster.error)return h({error:roster.error.message},500);
        if(!roster.data)return h({error:"Cette blessure ne concerne pas un joueur du groupe géré."},403);
      }

      const cfg=plans[protocol];
      const playerPlan=await db.from("player_medical_plans").upsert({
        player_id:managedId,protocol,...cfg,updated_at:new Date().toISOString()
      },{onConflict:"player_id"}).select("*").single();
      if(playerPlan.error)return h({error:playerPlan.error.message},500);

      if(managedId===primaryId){
        const legacy=await db.from("medical_plan").upsert({
          id:"demo",protocol,...cfg,updated_at:new Date().toISOString()
        },{onConflict:"id"});
        if(legacy.error)return h({error:legacy.error.message},500);
      }

      const injuryUpdate=id>0
        ?db.from("injuries").update({treatment:protocol}).eq("id",id).eq("player_id",managedId)
        :db.from("injuries").update({treatment:protocol}).eq("player_id",managedId).eq("status","Active");
      const iu=await injuryUpdate;
      if(iu.error)return h({error:iu.error.message},500);

      if(id>0){
        await db.from("inbox_items").update({decision_status:"resolved",is_read:true})
          .eq("related_entity_type","injury").eq("related_entity_id",id);
      }
      const player=await db.from("players").select("name").eq("id",managedId).maybeSingle();
      await db.from("inbox_items").insert({
        kind:"medical",title:"Plan médical mis à jour",
        body:"Protocole de "+String(player.data?.name||"ce joueur")+" : "+protocol+".",
        action_route:"medical",is_read:false,
        related_entity_type:"player",related_entity_id:managedId,
        action_payload:{route:"medical",player_id:managedId}
      });
      return h({ok:true,player_id:managedId,plan:playerPlan.data});
    }

    if(action==="respond_media"){
      const choice=String(body?.choice||"").trim().toLowerCase();
      const result=await db.rpc("resolve_managed_media_event",{p_event_id:id,p_choice:choice});
      if(result.error)return h({error:result.error.message},500);
      const payload:any=result.data||{};
      if(payload.ok===false)return h({error:payload.reason||"Réponse média refusée"},409);
      await db.from("inbox_items").update({is_read:true,decision_status:"resolved"})
        .eq("related_entity_type","media_event").eq("related_entity_id",id);
      return h({ok:true,result:payload});
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


  if(path.endsWith("/api/history-players")&&req.method==="GET"){
    const q=(u.searchParams.get("q")??"").trim().slice(0,80);
    const country=(u.searchParams.get("country")??"").trim().toUpperCase().slice(0,3);
    const offset=n(u.searchParams.get("offset"),0,0,20000);
    const limit=n(u.searchParams.get("limit"),100,1,100);

    let hq=db.from("history_player_search").select("*",{count:"exact"});
    if(q)hq=hq.ilike("name",`%${q}%`);
    if(country)hq=hq.eq("country",country);
    hq=hq.order("history_score",{ascending:false}).range(offset,offset+limit-1);
    const page=await hq;
    if(page.error)return h({error:page.error.message},500);

    const ids=(page.data??[]).map((x:any)=>Number(x.id)).filter(Boolean);
    let details:any[]=[];
    if(ids.length){
      const d=await db.from("players")
        .select("id,career_high_rank,career_high_rank_date,weeks_at_no1,weeks_top10,weeks_top100,ranking_history_weeks,career_status,photo_url,birth_date")
        .in("id",ids);
      if(d.error)return h({error:d.error.message},500);
      details=d.data??[];
    }
    const byId=new Map(details.map((x:any)=>[Number(x.id),x]));
    const rows=(page.data??[]).map((x:any)=>({...x,...(byId.get(Number(x.id))||{})}));
    return h({offset,limit,count:page.count??0,rows});
  }


  if((path.endsWith("/api/history-leaders")||path.endsWith("/api/history-hub"))&&req.method==="GET"){
    const country=(u.searchParams.get("country")??"").trim().toUpperCase().slice(0,3);
    const continent=(u.searchParams.get("continent")??"").trim().slice(0,40);
    const limit=n(u.searchParams.get("limit"),300,1,500);
    const career=await db.from("career_state").select("career_date,managed_player_id").eq("id","demo").maybeSingle();
    const gameDate=String(career.data?.career_date||AGE_REFERENCE_DATE);

    const [historyRows,youthRows,ncaaRows,rankRecordRows,historyTotal] = await Promise.all([
      db.from("history_player_scores").select("*").order("history_score",{ascending:false}).limit(1500),
      db.from("players")
        .select("id,name,country,birth_date,age,ranking,points,junior_ranking,junior_points,itf_ranking,current_ability,potential,photo_url,game_generated,generated_year,ncaa_current,ncaa_school,career_status,data_source")
        .not("birth_date","is",null)
        .or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*")
        .order("ranking",{ascending:true,nullsFirst:false})
        .limit(2500),
      db.from("ncaa_player_registry").select("player_id,status,season,ita_rank,ita_rank_official,projected_rank,school,division,snapshot_date")
        .order("snapshot_date",{ascending:false}).limit(5000),
      db.from("players")
        .select("id,name,country,career_high_rank,career_high_rank_date,weeks_at_no1,weeks_top10,weeks_top100,ranking_history_weeks,ranking_history_source,ranking_history_cutoff")
        .gt("ranking_history_weeks",0)
        .or("data_source.is.null,data_source.not.ilike.*hidden duplicate merged into*")
        .limit(5000),
      db.from("history_player_search").select("id",{count:"exact",head:true})
    ]);
    const err=historyRows.error||youthRows.error||ncaaRows.error||rankRecordRows.error||historyTotal.error;
    if(err)return h({error:err.message},500);

    const rankRecordById=new Map((rankRecordRows.data??[]).map((x:any)=>[Number(x.id),x]));
    const allHistory=(historyRows.data??[]).map((x:any)=>({
      ...x,
      ...(rankRecordById.get(Number(x.id))||{}),
      continent:continentOf(x.country)
    }));
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
      win_pct:[...nationalPool].filter((x:any)=>Number(x.wins||0)+Number(x.losses||0)>=50).sort((a:any,b:any)=>Number(b.win_pct||0)-Number(a.win_pct||0))[0]||null,
      weeks_at_no1:bestBy("weeks_at_no1"),
      weeks_top10:bestBy("weeks_top10"),
      weeks_top100:bestBy("weeks_top100")
    };
    const rankingRecords={
      weeks_at_no1:[...allHistory].filter((x:any)=>Number(x.weeks_at_no1||0)>0).sort((a:any,b:any)=>Number(b.weeks_at_no1||0)-Number(a.weeks_at_no1||0)||Number(a.career_high_rank||9999)-Number(b.career_high_rank||9999)).slice(0,30),
      weeks_top10:[...allHistory].filter((x:any)=>Number(x.weeks_top10||0)>0).sort((a:any,b:any)=>Number(b.weeks_top10||0)-Number(a.weeks_top10||0)).slice(0,30),
      weeks_top100:[...allHistory].filter((x:any)=>Number(x.weeks_top100||0)>0).sort((a:any,b:any)=>Number(b.weeks_top100||0)-Number(a.weeks_top100||0)).slice(0,30)
    };

    const ageRows=(youthRows.data??[]).map((p:any)=>({...p,age:ageAt(p.birth_date,AGE_REFERENCE_DATE,p.age,p.age_snapshot_date),continent:continentOf(p.country)}));
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
    const requestedRecordPlayerId=n(u.searchParams.get("player_id"),0,0,99999999);
    const recordPlayerId=requestedRecordPlayerId||Number(career.data?.managed_player_id||0)||null;
    const recordHub=await db.rpc("court_boss_record_hub",{p_player_id:recordPlayerId,p_date:gameDate});

    return h({
      methodology:"Indice Court Boss: 10 000/Grand Chelem + 2 200/ATP Finals + 1 200/Masters + 180/autre titre + 2/victoire enregistrée. Ce n'est pas un classement officiel du GOAT.",
      filters:{country:country||null,continent:continent||null},
      rows:pool.slice(0,limit),
      countryBest:countryBest.slice(0,100),
      continentBest,
      hallOfFame,
      grandSlamRecords,
      nationalRecords,
      rankingRecords,
      recordHub:recordHub.error?{error:recordHub.error.message}:recordHub.data,
      u18,u21,
      coverage:{
        players:pool.length,
        historicalPlayers:Number(historyTotal.count||allHistory.length),
        countries:new Set(allHistory.map((x:any)=>x.country)).size,
        ncaaProfiles:ncaaProfiles.size,
        ncaaActive:ncaaActive.size,
        gameDate
      }
    });
  }

  if(path.endsWith("/api/world")&&req.method==="GET"){
    const stats=await db.rpc("court_boss_world_stats");
    if(stats.error)return h({error:stats.error.message},500);
    return h(stats.data??{
      rankingReferenceDate:"2025-12-01",
      worldRankingCapacity:30000
    });
  }


  if(path.endsWith("/api/new-career")&&req.method==="POST"){
    const browserKey=saveId(req); if(!browserKey)return h({error:"Invalid save key"},400);
    const baseline=await ensureCareerBaselineTemplate();
    if(!baseline.ok)return h({error:"Le modèle de nouvelle carrière n'est pas disponible.",reason:baseline.reason||"template_missing"},409);
    const template=await db.from("game_career_templates").select("*").eq("id","default-2025-12-01").maybeSingle();
    if(template.error||!template.data)return h({error:template.error?.message||"Modèle de carrière introuvable"},404);
    const restored=await restoreManagedSaveSnapshot(template.data.managed_snapshot);
    const payload=template.data.local_payload&&typeof template.data.local_payload==="object"?template.data.local_payload:{};
    const legacy=await db.from("game_saves").upsert({
      id:browserKey,payload,updated_at:new Date().toISOString()
    },{onConflict:"id"});
    if(legacy.error)return h({error:legacy.error.message},500);
    const c=await db.from("career_state").select("career_date,week,player_name,managed_player_id").eq("id","demo").maybeSingle();
    await db.from("career_event_log").insert({
      event_date:c.data?.career_date||AGE_REFERENCE_DATE,week:Number(c.data?.week||1),
      system:"career",event_type:"new_career",entity_type:"player",entity_id:c.data?.managed_player_id||null,
      summary:"Nouvelle carrière démarrée",payload:{template:"default-2025-12-01",snapshot_model:restored.model}
    });
    return h({ok:true,model:"CB-NEW-CAREER-v1",local_payload:payload,career:c.data??null,restored});
  }

  if(path.endsWith("/api/save-slots")&&req.method==="GET"){
    const browserKey=saveId(req); if(!browserKey)return h({error:"Invalid save key"},400);
    const slots=await db.from("game_save_slots")
      .select("id,slot_no,slot_type,slot_name,career_date,week,player_name,managed_player_id,snapshot_scope,game_version,created_at,updated_at")
      .eq("browser_key",browserKey)
      .order("slot_no",{ascending:true});
    if(slots.error)return h({error:slots.error.message},500);
    return h({ok:true,slots:slots.data??[],model:"CB-SAVE-SLOTS-v2"});
  }

  if(path.endsWith("/api/save-slot")&&req.method==="POST"){
    const browserKey=saveId(req); if(!browserKey)return h({error:"Invalid save key"},400);
    let body:any; try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const slotNo=n(body?.slot_no,0,0,9);
    const slotType=["manual","autosave","quick"].includes(String(body?.slot_type||"manual"))?String(body?.slot_type||"manual"):"manual";
    const slotName=String(body?.slot_name||(
      slotType==="autosave"?"Autosave":slotType==="quick"?"Sauvegarde rapide":"Sauvegarde "+slotNo
    )).slice(0,80);
    const baseSnapshot=await captureManagedSaveSnapshot();
    let snapshot:any=baseSnapshot;
    // Manual and quick saves are true in-match checkpoints. Autosave remains a
    // pre-match rollback boundary so a ragequit never silently commits live points.
    if(slotType!=="autosave"){
      const livePlayerIds=[...new Set([
        Number(baseSnapshot.managed_player_id||0),
        ...((baseSnapshot.managed_players??[]).map((x:any)=>Number(x.id||0)))
      ].filter(Boolean))];
      let liveSessions:any[]=[];
      let liveEvents:any[]=[];
      let livePointEvents:any[]=[];
      if(livePlayerIds.length){
        const live=await db.from("live_match_sessions")
          .select("*").in("managed_player_id",livePlayerIds).in("status",["active","finished"]).order("id");
        if(live.error)return h({error:live.error.message},500);
        liveSessions=live.data??[];
        const liveIds=liveSessions.map((x:any)=>Number(x.id)).filter(Boolean);
        if(liveIds.length){
          const [events,pointEvents]=await Promise.all([
            db.from("live_match_events").select("*").in("session_id",liveIds).order("id"),
            db.from("live_match_point_events").select("*").in("session_id",liveIds).order("id")
          ]);
          if(events.error||pointEvents.error)return h({error:(events.error||pointEvents.error)?.message},500);
          liveEvents=events.data??[];
          livePointEvents=pointEvents.data??[];
        }
      }
      snapshot={
        ...baseSnapshot,model:"CB-MANAGED-SAVE-v7",
        live_match_sessions:liveSessions,
        live_match_events:liveEvents,
        live_match_point_events:livePointEvents
      };
    }
    const snapshotScope=String(snapshot.model)==="CB-MANAGED-SAVE-v7"?"managed_squad_live_checkpoint_exact_v7":String(snapshot.model)==="CB-MANAGED-SAVE-v6"?"managed_squad_ledgers_exact_v6":String(snapshot.model)==="CB-MANAGED-SAVE-v5"?"managed_squad_ledger_exact_v5":String(snapshot.model)==="CB-MANAGED-SAVE-v4"?"managed_squad_exact_v4":String(snapshot.model)==="CB-MANAGED-SAVE-v3"?"managed_academy_exact_v3":"managed_world_exact_v2";
    const saveGameVersion=String(snapshot.model)==="CB-MANAGED-SAVE-v7"?"2026.10-career-os-v7":String(snapshot.model)==="CB-MANAGED-SAVE-v6"?"2026.10-career-os-v6":String(snapshot.model)==="CB-MANAGED-SAVE-v5"?"2026.10-career-os-v5":String(snapshot.model)==="CB-MANAGED-SAVE-v4"?"2026.10-career-os-v4":String(snapshot.model)==="CB-MANAGED-SAVE-v3"?"2026.10-career-os-v3":"2026.10-career-os-v2";
    const payload=body?.local_payload&&typeof body.local_payload==="object"?{...body.local_payload}:{};
    delete payload.liveSessionId;
    delete payload.liveMatch;
    delete payload.liveOpponent;
    delete payload.liveAuto;
    const save=await db.from("game_save_slots").upsert({
      browser_key:browserKey,slot_no:slotNo,slot_type:slotType,slot_name:slotName,
      local_payload:payload,managed_snapshot:snapshot,
      career_date:snapshot.career_date,week:snapshot.week,
      player_name:snapshot.career?.player_name||null,
      managed_player_id:snapshot.managed_player_id||null,
      snapshot_scope:snapshotScope,game_version:saveGameVersion,
      updated_at:new Date().toISOString()
    },{onConflict:"browser_key,slot_no"}).select("id,slot_no,slot_type,slot_name,career_date,week,player_name,updated_at").single();
    if(save.error)return h({error:save.error.message},500);
    const legacy=await db.from("game_saves").upsert({
      id:browserKey,payload,updated_at:new Date().toISOString()
    },{onConflict:"id"});
    if(legacy.error)return h({error:legacy.error.message},500);
    await db.from("career_event_log").insert({
      event_date:snapshot.career_date,week:snapshot.week,system:"save",event_type:"save_created",
      entity_type:"save_slot",entity_id:save.data.id,
      summary:"Sauvegarde "+slotName,
      payload:{slot_no:slotNo,slot_type:slotType,snapshot_scope:snapshotScope,snapshot_model:snapshot.model}
    });
    return h({ok:true,slot:save.data,snapshot_model:snapshot.model});
  }

  if(path.endsWith("/api/load-slot")&&req.method==="POST"){
    const browserKey=saveId(req); if(!browserKey)return h({error:"Invalid save key"},400);
    let body:any; try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const slotNo=n(body?.slot_no,0,0,9);
    const slot=await db.from("game_save_slots")
      .select("*").eq("browser_key",browserKey).eq("slot_no",slotNo).maybeSingle();
    if(slot.error||!slot.data)return h({error:slot.error?.message||"Sauvegarde introuvable"},404);
    const restored=await restoreManagedSaveSnapshot(slot.data.managed_snapshot);
    const loadedPayload=slot.data.local_payload&&typeof slot.data.local_payload==="object"?{...slot.data.local_payload}:{};
    delete loadedPayload.liveSessionId;
    delete loadedPayload.liveMatch;
    delete loadedPayload.liveOpponent;
    delete loadedPayload.liveAuto;
    const legacy=await db.from("game_saves").upsert({
      id:browserKey,payload:loadedPayload,updated_at:new Date().toISOString()
    },{onConflict:"id"});
    if(legacy.error)return h({error:legacy.error.message},500);
    await db.from("career_event_log").insert({
      event_date:slot.data.career_date||AGE_REFERENCE_DATE,week:slot.data.week||1,system:"save",event_type:"save_loaded",
      entity_type:"save_slot",entity_id:slot.data.id,
      summary:"Chargement "+slot.data.slot_name,
      payload:{slot_no:slotNo,snapshot_scope:slot.data.snapshot_scope}
    });
    return h({ok:true,slot:{slot_no:slot.data.slot_no,slot_name:slot.data.slot_name,career_date:slot.data.career_date,week:slot.data.week},local_payload:loadedPayload,restored,live_match_sessions:Array.isArray(slot.data.managed_snapshot?.live_match_sessions)?slot.data.managed_snapshot.live_match_sessions.map((x:any)=>({id:x.id,managed_player_id:x.managed_player_id,status:x.status})):[]});
  }

  if(path.endsWith("/api/delete-slot")&&req.method==="POST"){
    const browserKey=saveId(req); if(!browserKey)return h({error:"Invalid save key"},400);
    let body:any; try{body=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const slotNo=n(body?.slot_no,0,0,9);
    if(slotNo===0)return h({error:"Le slot autosave ne peut pas être supprimé."},409);
    const del=await db.from("game_save_slots").delete().eq("browser_key",browserKey).eq("slot_no",slotNo);
    return del.error?h({error:del.error.message},500):h({ok:true,slot_no:slotNo});
  }

  if(path.endsWith("/api/save")&&req.method==="POST"){
    const sid=saveId(req); if(!sid) return h({error:"Invalid save key"},400);
    let payload:any; try{payload=await req.json()}catch{return h({error:"Invalid JSON"},400)}
    const {error}=await db.from("game_saves").upsert({id:sid,payload,updated_at:new Date().toISOString()});
    return error?h({error:error.message},500):h({ok:true});
  }

  return h({error:"Not found"},404);
});

