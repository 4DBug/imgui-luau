-- Font pieces: ImFontGlyphRangesBuilder, ImFont:CalcWordWrapPosition() vs TextWrapped(), IsGlyphRangeUnused(),
-- stb_decompress + Decode85 via AddFontFromMemoryCompressedBase85TTF() (same glyphs/metrics as the raw TTF).
local G = require(game:GetService("ReplicatedStorage"):WaitForChild("ImGui"))
local ImGui, ImVec2 = G.ImGui, G.ImVec2
ImGui.CreateContext(); G.ImGui_ImplRoblox.Init()
local io = ImGui.GetIO()
local failed = {}
local function check(ok, msg) if not ok then table.insert(failed, msg); print("FAIL " .. msg) end end

-- GlyphRangesBuilder
local builder = G.ImFontGlyphRangesBuilder()
builder:AddText("Hello \u{e9}")
local ranges = G.ImVector()
builder:BuildRanges(ranges)
local got = table.concat(table.move(ranges.Data, 1, ranges.Size, 1, {}), ",")
check(got == "32,32,72,72,101,101,108,108,111,111,233,233,0", "BuildRanges " .. got)
builder:Clear()
builder:AddRanges(io.Fonts:GetGlyphRangesDefault())
builder:AddChar(0x41) -- already in range
ranges = G.ImVector(); builder:BuildRanges(ranges)
check(ranges.Size == 3 and ranges.Data[1] == 0x20 and ranges.Data[2] == 0xFF and ranges.Data[3] == 0, "AddRanges default")
check(builder:GetBit(0x20) and not builder:GetBit(0x1F) and not builder:GetBit(0x100), "GetBit")

-- stb-compressed + base85 ProggyClean.ttf (generated with an stb_compress-format encoder + binary_to_compressed_c's base85)
local B85 = ([==[
7])#######hV0qs#####]h?>#/:jl&Ql#v#[Zre=N=K_o(-(##mQ%##B>A0F_%#g(g/'##r[(##PF6'I</,GM*BiC$v%###s,0%J*RB8O+d68%eKRrQ(.d<BW_*vCL%###E%###:d@UC%)BE#=.>>#'####<_[FH
O97MKO->>#i6YY#i1JuB5eI`[VRUV$=.<T7oH[^ICAS5#T.>>#K####+>00FnH/5`S7g1TS->>#k%S+Hot3>MYJGiTLPUV$>eFVCUwS>#9G:;$n%###Sh(a1aA.;6BE-hAeI1=#au8eZ2D$CI[Mn20Gb?=iMPrIL
DSGkFI5>##Q+`AMB%]`ac<%##CFgn*<WFX:&M'^#3@:B#`2B2#[0b30lOj)#-####.%*=Cvf./LVSiHdaT_n#X$###csu8.r:%)34Dk>$<,;.OOMDgEKnIS7EM9>ZoSAZ$*3)qMQv//L^MkA#wmCAMUnG<-7F>HM
DHw>Pt*p+M[ul=Q<O]CPUoINNUm+p7S<oG76Mqr)twv9Mt0[0#=S&r;QDqk+SEqFR@0p--.iPDN+Y')$PP;vnQbxRMqJQ*OD:H-M#C]GQJ-jBPO&%^Qmus+M3@C58qNO&#sNk,%?$xu#Fle&,W6=G2,Hb;-;wcP$
tPBuuE1V:vm3SML+x0B#/Dabh^KfW-j(.`&V8WQ-2$ZtQQpp5#l,$R#=`i['#l+S#Q*IX#6GMk#op/i#:n*x#tJV0$t#F=$X6iC$1/oh$TrKb$S/kt$&,)O%=q]E%o]n[%6dRd%lGTq%_#`C&$T1_&>Y^Y&2wbq&
TB-K'@IZC'%]#V'Uv'n'[R%1(D6?c(OD1$)e>Lr(Z*24)C5Yb)R/uY)#PPj)uaFu)pEt**@7KY*j<MS*5Nki*SAC?+x/x5+ugwH+;f6w+**;8,V?'+,3Y6W,pGkM,sgEa,%5h7-QbL,-Z8sL-.[r<-r;tI-5hnl-
Cnqc-CX86.QEKF.,hI9.1W`S%mQrV[C4s&#t3&KDU+DvZ)$SpA>O*dskh5??pb?^Y44[W7m@O9&/?o&YNgT?-'aPdsd(-qA0[9_#WMT9AcO#wm%e;e3?oWq/R1,XIghlWnL4mEX_v(R^+$4:A6.*x6Y+w_,ED)`,
PIDRpbf::fN$F.N4Bv:/>80xm6wgLiuWsFXrv)AHt/sl19::#%T1?Ynm49;SFb8/N7n.a><s3T0OpXm(4@4sf)_W/WEcIZ70Ne5_QYMTBLMbT0%t4Tph<HT^;n@*>$P%O)]J/0j$)macqO]pg2V2u$&t@##5f1$#
E@%%#Uqn%#fKb&#v&U'#0WH(#@2<)#Pc/*#a=#+#qnl+#+I`,#;$S-#KTF.#[/:/#l`-0#&;w0#6lj1#oiFJ('Moe2;4HZ$mgfX-b/g/HIt71#DRT<Lq8%dM$bLDNoaVV-Pm^dOJ@6##XaYx')_#&4Za=sQ-,7&4
Oe)>Pn<<>P0]15/$[K<Lrhci9h&@2LaX:9$;$Ne?L*'?76@Vp.%XK<LdcPe6%l^>$?:b1#^QZ`*uqmV-8lt.ZRwbVRqjtH*PhBQ(-t]N-0*aYMiEVq7a=W4#`6_c)$/*JL(L-^(]$wIMlcs(UsvHv,,rbA#/2u]O
hdcHMucWU-k^n:$VGR;oFHnq7e(Q&#uDdE&];bLcqC/^daSxFNtTGw.P3w.Ln1k,O7$22%r]<WS?OY)NJ[vI:DJNGokW_'6Q;I28n8X,Okie;)sJl_fawt-$II`;-sINN$tre+MLFg;-cG,-M<vp%N`tb48]_c6s
:#^#$J?HC$,>2U%qS#n8as:jrQ=$##/)>uuN?Sq7^fV2ivEjJN-MT;-UJ;QMM=6##Cni&O1/Ut'7#[UN>+]K3M@2+8UkW1#k.WUN4DU;-j8(1$)[888aOHpgh<7r7#n8I?%R7p7tGF]u%OtlSE4$##6We'8SdfFI
WVZ>nZ6c8MPhc(.i10p7x0'.=;lxb-4r'E>qC0%%?].e;I#72LclTAO0qD>$Vvnq2h^fW-LL4OiYW-mNFJuH&O(35&85c58@<iv%VwpGMX#$*&WFjp'jZCx$5N:q8/sgd4LhC^++re_8de;m8?37w%RICm8o4wd+
*OhaW?_m.'3XYjM/gh.(xEe58>Y31#_Lx-[?u>q7:5i8K5(;mOM8#=Q'`+%&7'6i#BtxA?0KPM-1PHM&/esr7gC>B$1wGJ(>Q5t7]#:xT:tl.$Tvx;-%&26&`JT58^V_,FWN-c0F####HSI@1K<8FN&?bO'2[IfM
j'YWN,<hn3bqwJN0:kC:(Yf>et`e;)LBf68(24gj1WXW'afQfFv7V.8R02?[LUlDN3cha'&]T&#b96$2*T5s7L5jv[&tsR%3dG2M0.(58=RK=`37;ENkWl9)Y7dp7v_k;fk&Z31P>5r'ZC$M&7&i)<U/5F%<bj/:
b5vAmK4$##&J<j$&6G<QMA&D:Hbkxu.NTkM6ev.:XCF&#iR7S82tuF%k$IAOvjw:$ku0p7sTMBm9pUh$KAuu#5[,qpn%(.*;?>5SkFGm;i'72Ljb]1#+BcK:Fgs.F8`aBNT($28/7*.H1GrvqoTa2`b:EO-=sKj9
crw0#.4D.M(s<A+,DPc=mTGQ:uaAL:Wjp#(R^uw9KvsDN781]&6tgA=_$Dc%.7vcMO>m;51/tW8Y@@S/#1jn8BZT/-Y,lJa-2Ht$i=(HMv'(P8Y>4AuNb6j9hP6(d?^OE23b<Q8)H*nkb$M#1kJAqgUJSk8kK'dk
5#uk%xHA88V`;3;KicD%RE-RLwIsJ%#Et,krIK64v,N/Vn@^5+,(;eMs7jf%Pa64:0nhEYGlk%(I9x9Mk3AN9PV*1#m1OL;Y@0qb]2``]dhsp8HNDLPQ(C-M(NbS85^wek`P@'$fCAV8_hGWSE<?tO(=ZU*EK949
9ux0#2nKA=dT'^#>sR&ZePWV&-=i>RM-']:uc%4;r>8R$tZgSN$fo1#8&n/;%G7@[Jf4x+.bjq7rlBEYk>h-%(X8j9VCxj2OM:/1_>qs7fEt-$n17tQE&9A.S+Ne+3]a:%$MLp7t]Wx'>3Ks7wtpDP.%L)$Q]BDN
NOZf:iskA#j:8T@)BC[.<2N=8c4G`&EW<a&`aQd+s_Pp'a_&6(M@M.$:t1W?4@0#AKhL&OZr_G5Ndap''9nq&@EQkTL0>@$%,m/:PIh)P<e=K8`cI4;5/hu0$qVv[#aKm<Vh;BmVxk4%x3Kn9+Nkxu6Ro94fPQ:8
P_)edQ/G0MPJKU11j?NWE?N(80m^&v+J?J:DRPx^YwdHMNf4-:K3<p^FSfo7kKtWSvQjN9)v[B739$^*i-It]VKVv/>Eq3:+x&'-t0sc;>[:</nIMS2He60Vdig`&6]Hj9QO_&RvTf'&mZ]mBRJ3SabaG'?hIi.$
$./32CCP)NBxoO(9L(c%jxcp7a.-e4Y5n3-qg-a/9c639%wJ+G5X1e&?5V?-a?>Q-;4*88df9dk@]?Y'/ehS@A:R&m2_(:)QYJwTme-LEcuko$4B:T1=^J$&2(+@-]Ziu,ae_-tbUGDN`-Ra$;hhjW/v[lA3pKq^
H<;&(8#DwP3c)/-SoDu7GaHQ:AX=W%+7k,4dQ,N11A>2Bv%03M_/wU&oNi5A)(&3MslOf-.brg=5SHx#7jg]O.F`c)6jK788At1#UfqV-`K<h=Vdb-8U,$90QK@I-E8o3%$grI;4HtdX.Qs$9nga.-c;@v><=ijV
anS,,diDack,uG%(q-&>^Ep&?uTh&UIULu:N*DkDaoK>0T>R@@ho/P+uw<T8#pekXXLZ)GN?Hf,CHuU8&GTpTdx:O3h,p583DQa5frln2-eHrS`V[r7V<$+%Ej0HN,NbN&WQKP9p9qDP-L%r'r(Mj9P+3*GJ*2$/
4_R;-22R2$*LKj:':c_-%4+X.)=a78Q<x0#JP;'PY?=(&BgGp8r;7F%@<PWJYRkH,+GX&#9ePr^o1%/8JE#QUU8jn'S=uPA$TS'J)G=@>^$r?%=FY%8=cFU_Kffo7m-u8NI/5'$NF81.taNq7)?Kq^T+DB)Wg>jV
(ckS*I,1qAb-<p^7Mjf%NcuFNgX12)80EuK,1)g0jPmd;%aZp0ggZdM)j&Z$v>ZQS/U@)2.KDgU#Kk95sor>e@>(QYI<%Z*uB-x0*0K39$uQRX^T]M9_U?^?XD-:8t`MqM0pLP9BmS6(xp?e9dca,bq<3K*^w@T[
bub7%Vu;S8/G5F%0'8rVUDCnNj9%dMllOf-B)(Wf2(73)oGHH;IoZp0Q1Gp7%Wc&#v6D39^P()HBs(2';aFq72v6b6P77'&h2da<TJ_pT`rE)-rf,78tAk)>6Rm3/Zt8#QHo4`)XmW7h'<>e+2NgM9dboLavtx$$
KIK$>1fAoU4NP^0whIt7^iWx''x:Q:`PRB$lhV29)-.K<)dFu3^;mU8UO1S*KTJ/M$=Iw3qi6JN4AFoOalkGNhxNv'HM)?-0(Oh;0:aJsj[lT'5kWm83sdC%hHV7;LSb<S7du7IeKD'mS9JC9Jxr0$t8l>Pxwh9.
L,hs7Elx2)+C30*5d'q7#L?T0W#H^Zths.L2*578H]]^-nO,X&2/Z&FM9%%B8&E#>OgR?RC5'T*;Xx9RhdA7(L01H;Pk1NV87(p7Qd41#fFQ;-xe=C$uf['$C+RPs51b-<8x.4rJ;pt-aA,q7Z6QYq]s/FN6PT[%
gdf68Omx0#HA2s-tGPSIU*@w^dr,X/kJm;?T$dF#IwGP$hn1a*]p7,M.S?M9a$nx0;,Gp74,IpgKNdm'@Bt784N&:DUix*=bc^<Vh+&G[/;dFGR$=I$_Y##PPEV+8=uWd=5KWB%j&h'FPb84=_lDQ(Red/:KD/F.
-o'^#nvkQ8'FjZSZ96Y/o(,,M[jxJjk)lWNSaX%(x11$8SF=[.P8k2B>_sR8w[gJj7*:6:5`)QLb:^i?lw%rMgu>q78aq5M?^w>%IVPp7M8td=/H+s7>&d:;k:&qK=?ex%a*sYPO[+<%&K2;8;fD.$Wk@vPTlC:R
,9R>%-u#6AQ]m&6e32?%THYs%m-n58^<(0E=f2#$wonB$QB]m8R(7mMSpse*)jK29*O$90+$bk)VgB^m/i9R$)8LV4iPpdFBFX)-Q6s58&a3dX&TB59&@_[KAuJmSp13/%8Pp'5D2ZJ:j3:`f+5d+Nc2r.([59p7
6A#'v>J6u'm[2Q8CS+5rbs14$nK%B>m%6Q:`%P1):BA*N1a-A)96D3#1TCt7#IgE#U/VR=`(qQ(U:c58:RRPDZ+,58@`EdtKP>[PQd/,M9u#>9d*-g)&%B@-j<1e(>ih29via.-S?5`8FO:;B&?ch'PMk8@YG@*n
P@st7QGt-$,``wP[ZNC(uTEq70l)?[nS$i$FKgS8jJN9B<kU';c$/32mbBD$4;qeM?5R=MB:K'd@-K^&L.M'Oq4n2$SK%+dwY&(m7/HJ.emw-MLS]0)75,S32BtQ8f3;nqGb=<%Ckb69s#Z&Q^OVv-/vOp7:Mh,F
s2K1:'.vhOt3QA%7rt:(?h+G%2V:<@?O#Qqkl2$;YqE#1:xK,M&%uW)DLo;oA^4e1cnV2([,HKDk)U/dN+dP8:N-Up5d1$1LNP^=EMv^ZR7cP8$Obx%xL>p'CUH-MgU,3D7)D_0'?D_=g>d&QMFJk*7&Pp7Gt3[T
TwY+Y0v2o0DvI^#s-%g:26KE>o_`h*%L^VH1LbC=3;xji-O7r'Lf7KW4N+[&i7PW87O,i8DUjTBFRS?$UG1o*(VRd;4QG1#mpl%$>iraIcDKQ(d%g4(L@Q.Mv?^O&gCAr7t$.Ae*b8k&;1=6`d=_d'-05fD.D)E.
uFxZ(d4vQ8.(J(8.%NX-X3RpK:'oLabx4I-1q.:)0.<q0/jF88;0ESCEE8SRN0]u:kpB+$eu*a*2XTe;?@)%IZ[./$HD]BfZ1jk9iCJ32e9R78a=)c<)]<T^'Kc'@lKLKE,LNn%%cl-MpehT$W2`l2b'nj959tT'
1wv*$&9#[JNAC]&[mtvPGwA5;ckQdb`;]R$I&gjDXVfh<NTX1#a8T;-*F:`$qqu,MVqgZ$R(*@II4?uuW%QW@4LoKYVb%R8tks-$HG<f;^31ObK;lR(U@k+MLa'VIt)LE%IrM7)wU:EN&W[39ijMG%#w4g:,Xw0#
w0[588iGJ$ps_>.,umo%x+B7$S)0p71m99pnERN93)9I$)#(IM_Yd>#6x;XCg]5<-3efW85,/n1#S]C'qqvcD2n4`8u9j<-E`Y%&`Qhg*tt2e$N$t49<#oW&^a*@,$^^dk7xK)$GJP/M>KO0&ND_j9>>P&#JuF.3
S<r>I:OPE*XF>dOo#P-(I7Vj;vrlm968R,tB,cS(]FeW&&O`9$-L-5#aS-Ak*o#iSuvYmTPpq9&E*n&%lBap7aS=r7jnP7Ah-]pK>xo_N]mjvPjtJ.2/*'W$4BFQ8bN((&WpULN`$^3i'@+G%.[#.$_6>3)jr[PA
&Wp5Uk_uk%Hk@bNH`(S%T)p/MdebV$4iQr7(QMG%k%8bRfU/L.bn/mSCf>SI$`G%h9JSpB%>xsF,^-Ehgn*Q8&j]K<l(Md8m/9MmPZ4j`a4K2`eI,H:m*Zeohdc,X+fTuYcjEE%M^5t7YsvK3FWHI9$lM4#0*joT
?tM56R'Aq7$d95#n3nAI&'cm3Y(L-MnV#x'qj+l+liD.-8W;v>@wMQh=6)m$1_b-;I?Q5;7>`*6lg3G;sv&:`[JLN9w<gPqa/S/Mx@aJ%NNa,MG>gr'mKDKNrkdkasN/x0,l$q71^?Xh*X[8^PL*q%6cv58_S*1#
bX`0MITc080x^@ilsnlf[L7I%(3mLC(BZE5+?,P@)$+1#DqsJaN-U:/-u?68)p<9j7E%>i?Ia;-kH/D,v(mn8=0'.$Nu49@Bm*1#XYs5CvbQa86j-bS`c5m8RiE1#4l^&#pCa$UOs068Z1-E5RhYl$Oh%TW*)LTA
.#$]UnM;TK9(Dl%8`?6B<MiRWdaTl9'OGG.SAd[IOMvu>6E>WgZ3of$O1Up@XbS2L[OtL:aqtqK:M2j*_@-:)LF5F%sd40:3Fr_&]?'k9W@dF<A]r<J?&]lAL2j&-ntJ<(=skq7w^+Ls<q9et?<a^%+$Y98_&Zob
vsUqpARc=<ROu7c=ebbOHwO/6Pm@*Ww0]%X*io?<8IQ<iLwrMg?r?eO%E:^-aB#KWu<7b'tRLdt#'-;?A1^FEMk82bPU#-MT>uw&hMM8Ia^vr'sj#j1>f:^OuVh29)g09Tq-.78(S%?7NCU29fbbgNaEJ)<jB'4r
(OSP3WS698I9B.$?KS58QV`g$p=@`HW?U/5S&64;1n%:>7rU2`cGs_*,K)1#FCR(Q=Q7i8sDwUjLe.0M2('B$dwW88%vrv@bNOG%K8tMB`6XF-:/::;-:`6r0U=0$``Xp9Knp*-cUpeHl%w,;s+e<_3cs?-#s&r0
1B^]02M(wYNshr00dW_ZG]0a;Gx4ND*&9;-HM%VqIL6GDsDZki/S0K)KF,:pgT4,%4K]dM*x8h8WVl6`g#gG$mhmF,,i2v*wBS1MFM0`&,:PP:[J'LPk%']h5(Wxd>i9UXuQk&18(&H;%Ug'hT6S</?xNx1fa5u7
DW2QL',t`-Cx#okPutL<%cY'2pP)xPGHHiS^x6Z:R91ObU-iT9O(4m'+%2a*N9pP9(B.-bX%`XNve$U$Bht]=h6rJW<3VM%_j/'Q_7M3,ej5/-Ncf/sSl1]M(Q:['>v_Q93J04r7<,vNP%2d97xbEgJKQGVgB#r3
FO4;89*^EfckAhDPC)c<6v690M?r&(GDc^$Ki+58v&LnF)iRTRpw<8Up^,(dPss3,0Z)kT#1i]$-KIZ7LI)3S`ig1(p^^URhRi*N,%$c4L4udO(jG9%[vg2V7I(e&NY<dX,WKw#_&Yj9>hMBQ4T:r2`e0l:lJB$h
.`Pg+e]wY%jfNf$)']6K8lDKaC90I.p<3q7dQtA`Q`5?`(qQvc_6b,3O3)9gwixH-]$SR8vjMhdwMD$[V3xR&vCIpT$Vbk1f=RRblisvHe#Zq9Ske(9iR6XLQES29JsZIM-2>rDjiGr^89KO0-^'q718r_&61D58
w+r_&.lCW/6iG<-`*wQ%8DQ^OmBjE%9X`E.1EDS@#j/q'J5x8-cxfJssL4($Uflq7hxad=4O:C4K9+hER0^F9G+UQc8W:uQ&/0<A7t3fWC[J90AEOn%&:+kCUYXjd*c-^O.<(d%&0)1#XrV'POoOS$AX+q8IZ4)6
hxEFM,hSgN0aEW+x/;N3xJk0&j`S.;edM2i9D+*0GJlB$x:(29wPX&#?l%oS.cb&#`i[`*lQ/,MH@-##FEV6NTF6##$l84N1w?AO>'IAOl%4a*0Y^GM#RcGM9#ult_Ks$#B@`T.1rC$#`@`T.,Mc##T@`T.74i$#
WrG<-N2:W.2`($#irG<-<q@u-?Wd`*eC;,M6WYdM6WYdM*?`T.HEX&#`YYdM6WYdM6WYdM%w@(#.E-(#cPc-NZxtk24Y($Jt1^oD0ZKKFg`]oD+,2eGc:@bHcFx.>@nuc<)0o6D]bdUCFdg+>?Wae3;BR12A::MB
h]8;-?(DYGUq`uGNDw1B];8;-SHpw'r?Z.#K0f-#=ic+#E<x-#ZZO.#L)1/#wtu+#F:F&#;)1/#O<x-#YSq/#(ZO.#wc-2MVC/$$;^?w^Gm/aNs*p+M&fsD#*J(v#.c_V$2%@8%6=wo%:UWP&>n82'B0pi'FHPJ(
Ja1,)N#ic)R;ID*VS*&+Zla]+_.B>,cF#v,_REmh1W@`$0u68%47no%8ONP&<h/2'@*gi'DBGJ(HZ(,)Ls_c)P5@D*TMw%+XfW]+](9>,a@pu,eXPV-iq18.m3io.qKIP/ud*20#'bi0'?BJ19if,=(N^o232;D3
7Jr%4;cR]4?%4>5C=ku5GUKV6Kn,87O0do7SHDP8Wa%29[#]i9`;=J:dSt+;hlTc;l.6D<pFm%=t_M]=xw.>>&:fu>*RFV?.k'8@2-_o@6E?PA:^v1Bikur-m-VS.qE75/u^nl/#wNM0'90/1+Qgf1/jGG23,))3
7D``3;]@A4?uwx4C7XY5GO9;6Khpr6O*QS7hPn:ZKe0GMgc>c`Mq&Sn8h?YPLS-JUrBB`WH+,AO,Wm+MTm6fqOR(>PCeG`NqHn@k_;LfUox3creaQ(st)7VZ`5Quc4R>MBmeu:QS(f7eQfi:di++PfiuIoe1#Don
^w>igqOb1g:-r+DPn?VQ$(_.hbS8GDRI]1pm*m(EM(1DER=L`E2m(GVYq)>G['EYGbKAVHdW]rH0%]4ol2u4Jn>:PJsSUlJ(UFcVwl6MK%53JLTUxLpbwnWH#N#hF@0*K2,4IL2fCd<-gCd<-hCd<-iCd<-jCd<-
kCd<-lCd<-mCd<-nCd<-@Dd<-ADd<-BDd<-CDd<-DDd<-EJ)X-v0P]'Gt.g2Gt.g2Gt.g2Gt.g2Gt.g2Gt.g2Gt.g2Gt.g2Gt.g2Gt.g2Gt.g2Gt.g2Gt.g2TmOh2Y#oTC$NXVCThmfGY4&>-K*IT-K*IT-K*IT-
K*IT-K*IT-K*IT-K*IT-K*IT-K*IT-K*IT-K*IT-K*IT-K*IT-K*IT-18ZI'Et,gjm,(DPO/(DPO/(DPO/(DPO/(DPO/(DPO/(DPO/(DPO/(DPO/(DPO/(DPO/(DPO/(DPO/(DP+-XlC#m8Atkt>Ns
]==]):gsub("\n", "")

local raw_data, raw_size = G.ImStd.ImFileLoadToMemory("fonts/ProggyClean.ttf", "rb")
local raw = io.Fonts:AddFontFromMemoryTTF(raw_data, raw_size, 13.0)
local comp = io.Fonts:AddFontFromMemoryCompressedBase85TTF(B85, 13.0)
check(comp ~= nil, "AddFontFromMemoryCompressedBase85TTF returned nil")
local comp_data = comp.Sources.Data[1].FontData
local same = comp.Sources.Data[1].FontDataSize == raw_size
for n = 1, raw_size do if not same then break end same = comp_data[n] == raw_data[n] end
check(same, "decompressed bytes differ from fonts/ProggyClean.ttf")

local TEXT = "The quick brown fox jumps over the lazy dog again and again"
local W = 100
local f = 0
game:GetService("RunService").Stepped:Connect(function()
    f += 1
    G.ImGui_ImplRoblox.NewFrame()
    ImGui.NewFrame()
    ImGui.SetNextWindowPos(ImVec2(10, 10)); ImGui.SetNextWindowSize(ImVec2(400, 300))
    ImGui.Begin("Fonts")
    ImGui.PushFont(raw, 13.0)
    ImGui.PushTextWrapPos(ImGui.GetCursorPosX() + W)
    ImGui.TextWrapped(TEXT)
    local wrapped_h = ImGui.GetItemRectSize().y
    ImGui.PopTextWrapPos()
    local line_h = ImGui.GetTextLineHeight()
    ImGui.PopFont()
    if f <= 3 then
        ImGui.PushFont(comp, 13.0)
        ImGui.Text("Hello \u{e9}")
        ImGui.PopFont()
    end
    ImGui.End()
    ImGui.Render(); G.ImGui_ImplRoblox.RenderDrawData(ImGui.GetDrawData())

    if f == 3 then
        -- CalcWordWrapPosition(): same line breaks as TextWrapped(). ProggyClean 13px = 7px per char -> 14 chars per 100px line
        local te = #TEXT + 1
        local s, lines, breaks = 1, 0, {}
        while s < te do
            local e = raw:CalcWordWrapPosition(13.0, TEXT, s, te, W)
            lines += 1; table.insert(breaks, e)
            s = e
            while s < te and TEXT:sub(s, s) == " " do s += 1 end -- ImTextCalcWordWrapNextLineStart(): skip blanks
        end
        check(breaks[1] == 10, "first wrap after 'The quick': " .. tostring(breaks[1])) -- "The quick" | "brown fox" | ...
        check(TEXT:sub(11, breaks[2] - 1) == "brown fox", "second line '" .. TEXT:sub(11, breaks[2] - 1) .. "'")
        check(wrapped_h == lines * line_h, ("TextWrapped height %s vs %d lines * %s"):format(wrapped_h, lines, line_h))

        -- Compressed font: same glyphs and metrics as the raw TTF
        local br, bc = raw:GetFontBaked(13.0), comp:GetFontBaked(13.0)
        check(br.Ascent == bc.Ascent and br.Descent == bc.Descent, "ascent/descent")
        for _, c in { 0x48, 0x65, 0x6C, 0xE9, 0x41, 0x7E } do
            local gr, gc = br:FindGlyph(c), bc:FindGlyph(c)
            check(gc.Visible and gc.X1 > gc.X0 and gc.Y1 > gc.Y0, "compressed glyph empty " .. c)
            check(gr.AdvanceX == gc.AdvanceX and gr.X0 == gc.X0 and gr.Y0 == gc.Y0 and gr.X1 == gc.X1 and gr.Y1 == gc.Y1, "glyph metrics " .. c)
        end
        local str = "Hello \u{e9}"
        local sr, sc = raw:CalcTextSizeA(13.0, 1e30, 0, str, 1, #str + 1), comp:CalcTextSizeA(13.0, 1e30, 0, str, 1, #str + 1)
        check(sr.x == sc.x and sr.y == sc.y and sc.x > 0, "CalcTextSizeA")
        check(not comp:IsGlyphRangeUnused(0, 255) and comp:IsGlyphRangeUnused(0x4E00, 0x9FFF), "IsGlyphRangeUnused")

        -- AddRemapCodepoint(): '$' loads the 'A' glyph (applies to glyphs loaded afterwards: new 20px baked)
        comp:AddRemapCodepoint(0x24, 0x41)
        local b20 = comp:GetFontBaked(20.0)
        local gd, ga = b20:FindGlyph(0x24), raw:GetFontBaked(20.0):FindGlyph(0x41)
        check(gd.X0 == ga.X0 and gd.Y0 == ga.Y0 and gd.X1 == ga.X1 and gd.Y1 == ga.Y1, "AddRemapCodepoint")

        -- RemoveCustomRect()
        local atlas = io.Fonts
        local id = atlas:AddCustomRect(8, 8)
        check(atlas:GetCustomRect(id, G.ImFontAtlasRect()) == true, "AddCustomRect")
        atlas:RemoveCustomRect(id)
        check(not atlas:GetCustomRect(id, G.ImFontAtlasRect()), "RemoveCustomRect")

        -- RemoveFont()
        local nfonts, nsrc = atlas.Fonts.Size, atlas.Sources.Size
        atlas:RemoveFont(comp)
        check(atlas.Fonts.Size == nfonts - 1 and atlas.Sources.Size == nsrc - 1 and not atlas.Fonts:contains(comp), "RemoveFont")

        -- ImFontAtlasTextureBlockFill(), ImTextureDataGetXXXName()
        local tex = G.ImTextureData(); tex:Create(G.ImTextureFormat.RGBA32, 4, 4)
        G.ImFontAtlasTextureBlockFill(tex, 1, 2, 2, 1, G.IM_COL32(1, 2, 3, 4))
        local px = table.concat(tex.Pixels, ",", 33, 48)
        check(px == "0,0,0,0,1,2,3,4,1,2,3,4,0,0,0,0" and tex.Pixels[29] == 0 and tex.Pixels[53] == 0, "TextureBlockFill " .. px)
        check(G.ImTextureDataGetStatusName(tex.Status) == "WantCreate" and G.ImTextureDataGetFormatName(tex.Format) == "RGBA32", "texture names")
    end
    if f == 5 and #failed == 0 then print("FONTS OK") end
end)
