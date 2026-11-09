import {beforeEach,describe,expect,it,vi} from "vitest";
import {BatchGetCommand,QueryCommand} from "@aws-sdk/lib-dynamodb";
import type {APIGatewayProxyEventV2} from "aws-lambda";
const {send}=vi.hoisted(()=>({send:vi.fn()}));
vi.mock("../src/lib/dynamo",async(original)=>({
  ...(await original<typeof import("../src/lib/dynamo")>()),
  ddb:{send},
}));
import {getRanking,getRankingVisibility} from "../src/api/routes/ranking";
const a="aaaaaaaaaaa",b="bbbbbbbbbbb",c="ccccccccccc",d="ddddddddddd";
const work=(id:string,privacy:"public"|"unlisted"|"private"|"deleted",published=true)=>({
  pk:"WORK#"+id,sk:"META",itemType:"WORK",workId:id,
  authorId:"author",channelName:"author",
  title:"title:"+id,thumbnailUrl:"private-thumbnail:"+id,
  youtubeUrl:"https://www.youtube.com/watch?v="+id,
  youtubePrivacyStatus:privacy,isNiarimPublished:published,
  bookmarkCount:12,postedAt:"2026-11-09T12:00:00Z",tags:[],lockedTags:[],
});
const ev=(period?:string,ids?:string)=>({
  queryStringParameters: ids===undefined?{limit:"25"}:{ids},
  headers:{},
}) as unknown as APIGatewayProxyEventV2;
const body=(reply:any)=>JSON.parse(reply.body??"{}");
const works=[work(a,"public"),work(b,"private"),work(c,"unlisted"),work(d,"deleted")];
beforeEach(()=>{
 process.env.TABLE_NAME="test";
 send.mockReset();
 send.mockImplementation(async(command:any)=>{
   if(command instanceof QueryCommand){
     const pk=command.input.ExpressionAttributeValues?.[":pk"];
     if(pk==="BOOKMARK_RANKING"){
       return {Items:works.map(x=>({...x,gsi2pk:"BOOKMARK_RANKING",gsi2sk:12}))};
     }
     return {Items:works.map((x,i)=>({
       itemType:"BOOKMARK_PERIOD_SCORE",workId:x.workId,score:40-i,
     }))};
   }
   if(command instanceof BatchGetCommand){
     const keys=command.input.RequestItems?.test?.Keys??[];
     return {Responses:{test:works.filter(x=>
       keys.some((k:any)=>k.pk===x.pk))}};
   }
   throw Error("unexpected command "+command.constructor.name);
 });
});
describe("ranking visibility & rank stability contract",()=>{
 it("all-time fresh retrieval excludes private and deleted, includes public/unlisted",async()=>{
   const reply=body(await getRanking(ev(),"bookmarks"));
   expect(reply.works.map((w:any)=>w.workId)).toEqual([a,c]);
   expect(JSON.stringify(reply)).not.toContain("private-thumbnail:"+b);
   expect(JSON.stringify(reply)).not.toContain("private-thumbnail:"+d);
   expect(send.mock.calls.some(([cmd])=>cmd instanceof BatchGetCommand &&
     cmd.input.RequestItems?.test?.ConsistentRead===true)).toBe(true);
 });
 it("period retrieval filters private/deleted BEFORE calculating visible rank",async()=>{
   const reply=body(await getRanking(ev(),"daily"));
   expect(reply.works.map((w:any)=>w.workId)).toEqual([a,c]);
   expect(reply.works.map((w:any)=>w.periodBookmarkCount)).toEqual([40,38]);
 });
 it("visibility refresh redacts previously ranked slots without leaking metadata",async()=>{
   const prior=body(await getRanking(ev(),"daily")).works.map((w:any)=>w.workId);
   // One of the two initially eligible works is privatized after ranking fetch.
   works[2]=work(c,"private");
   const now=body(await getRankingVisibility(ev(undefined,prior.join(","))));
   expect(now.visibility).toEqual({[a]:true,[c]:false});
   expect(JSON.stringify(now)).not.toContain("title:");
   // Client keeps slot indices 0,1 and replaces only slot 1 with a tombstone.
   const snapshot=prior.map((id:string)=>now.visibility[id]?id:"REDACTED");
   expect(snapshot).toEqual([a,"REDACTED"]);
 });
 it("nonexistent identifiers are indistinguishable from hidden works",async()=>{
   const result=body(await getRankingVisibility(ev(undefined,[a,"zzzzzzzzzzz"].join(","))));
   expect(result.visibility).toEqual({[a]:true,zzzzzzzzzzz:false});
 });
 it("rejects arbitrary query lengths and invalid identifiers",async()=>{
   await expect(getRankingVisibility(ev(undefined,"../../etc/passwd"))).rejects.toThrow();
   await expect(getRankingVisibility(ev(undefined,Array(51).fill(a).join(",")))).rejects.toThrow();
 });
});
