#Pkg.add("PhyloNetworks");
#Pkg.add("DataFrames");
#Pkg.add("Dates")
#Pkg.update();

if length(ARGS) != 1
  error("need 1 parameter: the address of the directory")
end
directory = ARGS[1]; # read the directory

# Set the current working directory to be user's input address

dir = string("$(homedir())",directory);
cd(dir);

fileNames = filter(x->contains(x,".log"),readdir(pwd())); # Read only the names of *.log files

# The function is used to read the starting time of two runs and return the
# difference which is the consuming time for one run.

using Dates;

function eachRunTimeSummary(x,y)
    dat1 = DateTime(x, "e d u y H:M:S") - (
               contains(x, "AM") ? Hour(12) : Hour(0));
    dat2 = DateTime(y, "e d u y H:M:S") - (
               contains(y, "AM") ? Hour(12) : Hour(0));
    Diff = Float64(dat2 - dat1)/1000;
    return Diff
end

# Initialize the arrayList to save all the information we want for each run.

parameterInfo = Array{String}(8); # The array to save eight parameters: hmax, ftolRel, ftolAbs, xtoLAbs, xtolRel, Nfails, likotolAbs and runs
parameterInfoList = Array{String}[]; # The arrayList to save the parameter array for each file
runSeed = Array{String}[]; # The arrayList used to store seed for each run
runLoglik = Array{String}[]; # The arrayList used to store loglikValue for each run
runTimeList = Array{Float64}[]; # The arrayList used to store the time for each run
runTopology = Array{String}[]; # The arrayList used to store the topology for each run
run = 0; # Count the total run number of all files

# Use a for loop to find information from each log file.

for i in fileNames[1:end]

    # Import bash command grep and sed to help search and grab the information we want.

    parameterInfo[1] = readstring(pipeline(`grep "hmax =" $i`, `grep -Eo "\d+"`)); # Find hmax
    parameterInfo[2] = readstring(pipeline(`grep -Eo "ftolRel=.*" $i`, `sed -E 's/ftolRel=(.*), fto.*/\1/'`)); # Find ftolRel
    parameterInfo[3] = readstring(pipeline(`grep -Eo "ftolAbs=.*" $i`, `sed -E 's/ftolAbs=(.*),/\1/'`)); # Find ftolAbs
    parameterInfo[4] = readstring(pipeline(`grep -Eo "xtolAbs=.*" $i`, `sed -E 's/xtolAbs=(.*), xto.*/\1/'`)); # Find xtolAbs
    parameterInfo[5] = readstring(pipeline(`grep -Eo "xtolRel=.*" $i`, `sed -E 's/xtolRel=(.*)\./\1/'`)); # Find xtolRel
    parameterInfo[6] = readstring(pipeline(`grep -Eo "failed proposals =.*" $i`, `sed -E 's/failed proposals = (.*), likt.*/\1/'`)); # Find Nfails
    parameterInfo[7] = readstring(pipeline(`grep -Eo "liktolAbs =.*" $i`, `sed -E 's/liktolAbs = (.*)\./\1/'`)); # Find liktolAbs
    parameterInfo[8] = readstring(pipeline(`grep -Eo "BEGIN: .*" $i`, `sed -E 's/BEGIN: (.*) run.*/\1/'`)); # Find number of runs

    push!(parameterInfoList,parameterInfo); # Save the parameter array of one file into the arrayList

    run = run + parse(Int,parameterInfo[8]);

    # Look for all the information we need for each run in one log file.

    mainseed = readstring(pipeline(`grep -Eo "main seed.*" $i`, `sed -E 's/main seed (.*)/\1/'`)); # Grab the main seed for repeating same running
    seed = split(readstring(pipeline(`grep -Eo "seed:.*" $i`,`sed -E 's/seed: (.*) for.*/\1/'`))); # Store the seed of each run
    push!(runSeed,seed); # Save the seed into the arrayList
    loglik = split(readstring(pipeline(`grep -Eo "loglik of best.*" $i`, `sed -E 's/loglik of best (.*)/\1/'`))); # Find the loglik value
    ##loglik = map(x->parse(Float64,x),a);
    push!(runLoglik,loglik);

    # Find the topology of each run.

    topology = Array{String}(parse(Int, parameterInfo[8]));
    topologyLine = split(readstring(`grep -A 1 "FINISHED SNaQ for.*" $i`),"\n")
    for j in 1:length(topology)
        topology[j] = topologyLine[3*j-1];
    end
    push!(runTopology,topology); # Save the topology for future comparison

    # Save the info of time in each run.

    runTime = Array{String}(parse(Int, parameterInfo[8])+1);
    runTimeLine = split(readstring(`grep -A 1 "seed:.*" $i`), "\n")
    for k in 1:parse(Int, parameterInfo[8])
        runTime[k] = runTimeLine[3*k-1];
    end
    endTimeLine = split(readstring(`grep -B 1 "MaxNet is.*" $i`),"\n");
    runTime[end] = endTimeLine[1];

    # Count the time used for each run.

    runTimeNum = Array{Float64}(parse(Int, parameterInfo[8]));
    for j in length(runTimeNum)
        runTimeNum[j] = eachRunTimeSummary(runTime[j],runTime[j+1]);
    end

    push!(runTimeList,runTimeNum); # Save the time info of runs in each file

end

# Use dataframe to help generate the table including the information of each run.

using DataFrames; # Contain the function DataFrame

# Initialize the arraies saving the information used as columns in DataFrame.

Hmax = Array{Int}(run);
Nfail = Array{Int}(run);
ftolRel = Array{Float64}(run);
ftolAbs = Array{Float64}(run);
xtolAbs = Array{Float64}(run);
xtolRel = Array{Float64}(run);
liktolAbs = Array{Float64}(run);

# Initialize the array so that it could be easy to combine in for loop.

seed = runSeed[1];
sameToBestTopology = Array{Int}(run);
loglik = runLoglik[1];
runTime = runTimeList[1];

# Repetitively set the parameters for each run.

for i in 1:length(parameterInfoList)
    for j in 1:parse(Int,parameterInfoList[i][8])

        Hmax[(i-1)*j+j] = parse(Float64, parameterInfoList[i][1]);
        Nfail[(i-1)*j+j] = parse(Float64, parameterInfoList[i][6]);
        ftolRel[(i-1)*j+j] = parse(Float64, parameterInfoList[i][2]);
        ftolAbs[(i-1)*j+j] = parse(Float64, parameterInfoList[i][3]);
        xtolAbs[(i-1)*j+j] = parse(Float64, parameterInfoList[i][4]);
        xtolRel[(i-1)*j+j] = parse(Float64, parameterInfoList[i][5]);
        liktolAbs[(i-1)*j+j] = parse(Float64, parameterInfoList[i][7]);

    end
end

# Combine all the values in the order of the runs.

for i in 2:length(fileNames)

    seed = [seed;runSeed[i]];
    loglik = [loglik;runLoglik[i]];
    runTime = [runTime;runTimeList[i]];

end

# Generate the DataFrame and write it into a csv file.

df = DataFrame(hmax=Hmax,nfail=Nfail,ftolRel=ftolRel,ftolAbs=ftolAbs,xtolAbs=xtolAbs,xtolRel=xtolRel,liktolAbs=liktolAbs,seed=seed,loglik=loglik,runTime=runTime);
writetable("output.csv",df)



