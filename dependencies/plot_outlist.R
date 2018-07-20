#/software/R-2.6.0/bin/R CMD BATCH --no-save  plot_outlist.R

#Read in files:
rin<-read.table("rin.dat", header = T, sep = "\t")
#bits    type    tax
#127.48  SEED    Eukaryota; Metazoa

rin2<-read.table("rinc.dat", header = T, sep = "\t")
#cnt     tax
#50      Eukaryota; Alveolata

#find the range and make a vector of binsizes for the histogram:
mx<-ceiling(max(rin$bits)+1)
mn<-floor(min(rin$bits)-1)
breaks <- seq(mn,mx,length.out=40)

#Make the histograms, but don't plot - hist sucks for multi-class data, use barplot instead:
halign<-  hist(rin$bits[rin$type=='FULL'],breaks=breaks,plot=F)
hseed <-  hist(rin$bits[rin$type=='SEED'],breaks=breaks,plot=F)
hnot  <-  hist(rin$bits[rin$type=='NOT'],breaks=breaks,plot=F)
hthresh<- hist(rin$bits[rin$type=='THRESH'],breaks=breaks,plot=F)

mxh<-max(halign$counts+hseed$counts+hnot$counts)

hspeciesCounts<-matrix(0, nrow = length(breaks)-1, ncol = length(rin2$tax), dimnames=list(floor(halign$mids),rin2$tax) );
tax<-matrix(rin2$tax)
for (i in seq(1,length(tax))){
   if(nchar(tax[i])<3) next;
   h<-  hist(rin$bits[rin$tax==tax[i]],breaks=breaks,plot=F)
   hspeciesCounts[,tax[i]]<-h$counts
}
hspeciesCounts<-t(hspeciesCounts)


#Make the matrix data structure that barplot likes:
hc<-c(halign$counts,hseed$counts,hnot$counts,hthresh$counts)

hbits<-matrix(hc,nrow = length(breaks)-1, ncol = 4, dimnames=list(floor(halign$mids),c("FULL","SEED","NOT","THRESH")))
hbits<-t(hbits)

#Do some work to find where to truncate the matrices. Jen's solution for the distributions with a HUGE number of low scoring hits:
cutoff<-1
for (i in seq(2,length(breaks)-1 )){
    if( hbits["THRESH",i] > 0 ){
             cutoff<-i
	     hbits["THRESH",i]<-1
	     break
    }
}

#Truncate 
hbitstrunc<- hbits[,cutoff:length(breaks)-1]
mxht<-max(hbitstrunc["FULL",]+hbitstrunc["SEED",]+hbitstrunc["NOT",])
mxh<-max(hbits["FULL",]+hbits["SEED",]+hbits["NOT",])

#Make sensible heights for the threshold bar:
hsumThresh<-hbits["FULL",i]+hbits["SEED",i]+hbits["NOT",i]
hbits["THRESH",]<-max(c(mxh-hsumThresh,0.1*hsumThresh))*hbits["THRESH",]
hbitstrunc["THRESH",]<-max(c(mxht-hbitstrunc[1,2]-hbitstrunc[2,2]-hbitstrunc[3,2],0.1*(hbitstrunc[1,2]+hbitstrunc[2,2]+hbitstrunc[3,2])))*hbitstrunc[4,]

#Make the plots:
pdf(file="outlist.pdf")
op<-par(mfrow=c(2,1),cex=0.75,las=2)
barplot(hbits,col=c("red","blue","purple","black"),xlab="CM score (bits)",ylab="Freq",main="Distribution of bit scores") 
legend("topright",c("FULL","SEED","NEITHER","THRESHOLD"),fill=c("red","blue","purple","black"),ncol=2)
barplot(hbits,col=c("red","blue","purple","black"),xlab="CM score (bits)",ylab="Freq",main="Distribution of bit scores (no legend)") 
barplot(hbitstrunc,col=c("red","blue","purple","black"),xlab="CM score (bits)",ylab="Freq",main="Truncated distribution of bit scores") 
legend("topright",c("FULL","SEED","NEITHER","THRESHOLD"),fill=c("red","blue","purple","black"),ncol=2)
barplot(hbitstrunc,col=c("red","blue","purple","black"),xlab="CM score (bits)",ylab="Freq",main="Truncated distribution of bit scores (no legend)") 
dev.off()

# accuracy<-read.table("outlist_accuracy.dat", header = T, sep = "\t")
# maxbitscore<-max(accuracy$THRESH)
# legxcoord<-0.2*maxbitscore
# txtxcoord<-0.8*maxbitscore
# maximcc<-which.max(accuracy$MCC)
# maxiacc<-which.max(accuracy$ACC)
# mcctxt<-paste("opt.MCC.thresh = ", accuracy$THRESH[maximcc], " bits")
# acctxt<-paste("opt.ACC.thresh = ", accuracy$THRESH[maxiacc], " bits")
# curtxt<-paste("current.thresh = ", thresh$V1[1], " bits")

# pdf(file="outlist.accuracy_stats.pdf")
# op<-par(mfrow=c(1,1),cex=0.75,las=2,lwd=2)
#  plot(accuracy$THRESH,accuracy$MCC,col="red",  lty=1, type="l", xlab="CM score (bits)",ylab="Accuracy measure",main="Accuracy measures",ylim=c(0,1.0))
# lines(accuracy$THRESH,accuracy$ACC,col="red",  lty=2)
# lines(accuracy$THRESH,accuracy$SEN,col="blue", lty=1)
# lines(accuracy$THRESH,accuracy$SPC,col="blue", lty=2)
# lines(accuracy$THRESH,accuracy$FDR,col="black",lty=1)
# lines(accuracy$THRESH,accuracy$FPR,col="black",lty=2)
# lines(c(thresh$V1[1],thresh$V1[1]),c(-1,2),col="black",lty=3)
# text(txtxcoord,0.88,curtxt)
# text(txtxcoord,0.84,mcctxt)
# text(txtxcoord,0.80,acctxt)
# legend(legxcoord,0.2,c("MCC","ACC","SEN","SPC","FDR","FPR"),col=c("red","red","blue","blue","black","black"),lty=c(1,2,1,2,1,2),ncol=3)
# dev.off()

#library(RColorBrewer)
require(graphics)
#Lab.palette <- colorRampPalette(c("black","red", "orange", "purple", "blue", "white"),
#                                    space = "Lab")
Lab.palette <- colorRampPalette(c("red", "orange", "yellow", "green", "cyan", "blue", "violet"),
                                    space = "Lab")
len<-length(tax)
len<-max(len,2)
pcols = rev(Lab.palette(len))
heatcol<-colorRampPalette(pcols)(len)

pdf(file="species.pdf")
op<-par(mfrow=c(1,1),cex=0.75,las=2)
barplot(hspeciesCounts,col=heatcol,xlab="CM score (bits)",ylab="Freq",main="Distribution of bit scores") 
legend("topleft",tax,fill=heatcol,ncol=3,cex=0.55)
dev.off()
