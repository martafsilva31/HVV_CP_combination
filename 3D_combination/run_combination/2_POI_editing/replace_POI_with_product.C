#include <TFile.h>
#include <RooWorkspace.h>
#include <RooRealVar.h>
#include <RooProduct.h>
#include <RooArgList.h>
#include <RooSimultaneous.h>
#include <RooAbsData.h>
#include <RooStats/ModelConfig.h>
#include <RooAbsPdf.h>
#include <RooArgSet.h>
#include <RooAbsArg.h>

#include <iostream>
#include <string>
#include <vector>
#include <list>

using namespace std;

struct FileEntry {
    string inputfilePath;
    string outputfilePath;
    string workspaceName;
    string variable_name;
    string channelname;
};

vector<FileEntry> files = {
    {"/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hTau/HTauTau_Data_linear.root", "/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hTau/HTauTau_Data_linear.root", "combined", "chbtilde", "HTauTau"},
    {"/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hTau/HTauTau_Data_linear.root", "/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hTau/HTauTau_Data_linear.root", "combined", "chwtilde", "HTauTau"},
    {"/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hTau/HTauTau_Data_linear.root", "/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hTau/HTauTau_Data_linear.root", "combined", "chbwtilde", "HTauTau"},
    {"/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hWW/HWW_Data_linear.root", "/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hWW/HWW_Data_linear.root", "HWW_ggFVBF_DPhijj_comb", "cHWBtil", "HWW"},
    {"/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hWW/HWW_Data_linear.root", "/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hWW/HWW_Data_linear.root", "HWW_ggFVBF_DPhijj_comb", "cHWtil", "HWW"},
    {"/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hWW/HWW_Data_linear.root", "/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hWW/HWW_Data_linear.root", "HWW_ggFVBF_DPhijj_comb", "cHBtil", "HWW"},
    {"/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hZZ/HZZ_Data_linear.root", "/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hZZ/HZZ_Data_linear.root", "combined", "cHWBtil", "HZZ"},
    {"/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hZZ/HZZ_Data_linear.root", "/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hZZ/HZZ_Data_linear.root", "combined", "cHBtil", "HZZ"},
    {"/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hZZ/HZZ_Data_linear.root", "/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hZZ/HZZ_Data_linear.root", "combined", "cHWtil", "HZZ"},
    {"/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hbb/hbb_Data_linear.root", "/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hbb/hbb_Data_linear.root", "combined", "cHWtil", "Hbb"},
    {"/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hTau/HTauTau_Data_quad.root", "/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hTau/HTauTau_Data_quad.root", "combined", "chbtilde", "HTauTau"},
    {"/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hTau/HTauTau_Data_quad.root", "/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hTau/HTauTau_Data_quad.root", "combined", "chwtilde", "HTauTau"},
    {"/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hTau/HTauTau_Data_quad.root", "/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hTau/HTauTau_Data_quad.root", "combined", "chbwtilde", "HTauTau"},
    {"/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hWW/HWW_Data_quad.root", "/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hWW/HWW_Data_quad.root", "HWW_ggFVBF_DPhijj_comb", "cHWBtil", "HWW"},
    {"/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hWW/HWW_Data_quad.root", "/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hWW/HWW_Data_quad.root", "HWW_ggFVBF_DPhijj_comb", "cHWtil", "HWW"},
    {"/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hWW/HWW_Data_quad.root", "/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hWW/HWW_Data_quad.root", "HWW_ggFVBF_DPhijj_comb", "cHBtil", "HWW"},
    {"/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hZZ/HZZ_Data_quad.root", "/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hZZ/HZZ_Data_quad.root", "combined", "cHWBtil", "HZZ"},
    {"/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hZZ/HZZ_Data_quad.root", "/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hZZ/HZZ_Data_quad.root", "combined", "cHBtil", "HZZ"},
    {"/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hZZ/HZZ_Data_quad.root", "/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hZZ/HZZ_Data_quad.root", "combined", "cHWtil", "HZZ"},
    {"/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hbb/hbb_Data_quad.root", "/project/atlas/users/mfernand/HVV_CP_comb/3D_combination/modified_ws/hbb/hbb_Data_quad.root", "combined", "cHWtil", "Hbb"}

};

void replace_cHWtil_with_product(const char* inputFileName, const char* outputFileName, const char* workspaceName, const char* variable_name, string channelname) {
    // Open input file
    TFile* inputFile = TFile::Open(inputFileName);
    if (!inputFile || inputFile->IsZombie()) {
        std::cerr << "Error: Cannot open input file " << inputFileName << std::endl;
        return;
    }

    // Load workspace
    RooWorkspace* ws = dynamic_cast<RooWorkspace*>(inputFile->Get(workspaceName));
    if (!ws) {
        std::cerr << "Error: Cannot load workspace '" << workspaceName << "'" << std::endl;
        inputFile->Close();
        return;
    }

    // Get original ModelConfig and pdf
    RooStats::ModelConfig* mc = dynamic_cast<RooStats::ModelConfig*>(ws->obj("ModelConfig"));
    if (!mc) {
        std::cerr << "Error: Cannot find ModelConfig" << std::endl;
        inputFile->Close();
        return;
    }

    RooSimultaneous* simPdf = dynamic_cast<RooSimultaneous*>(mc->GetPdf());

    // Create new workspace
    RooWorkspace newWs(workspaceName);

    // Define new variables
    RooRealVar* cHWtil_for_combine = new RooRealVar((std::string(variable_name) + "_combine").c_str(), (std::string(variable_name) + "_combine").c_str(), 0, -5, 5);
    RooRealVar* cHWtil_single = new RooRealVar((std::string(variable_name) + "_"+channelname).c_str(), (std::string(variable_name) + "_"+channelname).c_str(), 0, -5, 5);
    newWs.import(*cHWtil_for_combine);
    newWs.import(*cHWtil_single);

    // Create cHWtil = cHWtil_for_combine * cHWtil_single
    RooProduct* new_cHWtil = new RooProduct(variable_name,
        (std::string(variable_name) + "=" + (std::string(variable_name) + "_combine") + "*" + (std::string(variable_name) + "_"+channelname)).c_str(),
        RooArgList(*cHWtil_for_combine, *cHWtil_single));
    newWs.import(*new_cHWtil);

    // Copy all objects except the original variable
    TIterator* iter = ws->componentIterator();
    RooAbsArg* obj;
    while ((obj = dynamic_cast<RooAbsArg*>(iter->Next()))) {
        if (std::string(obj->GetName()) != variable_name) {
            newWs.import(*obj, RooFit::RecycleConflictNodes(), RooFit::Silence());
        }
    }
    delete iter;

    // Copy data
    std::list<RooAbsData*> dataList = ws->allData();
    for (auto it = dataList.begin(); it != dataList.end(); ++it) {
        newWs.import(**it);
    }

    // Re-import pdf
    newWs.import(*simPdf, RooFit::RecycleConflictNodes(), RooFit::Silence());

    // Create new ModelConfig with updated POIs
    RooStats::ModelConfig newMc("ModelConfig");
    newMc.SetWorkspace(newWs);
    newMc.SetPdf(*simPdf);
    newMc.SetGlobalObservables(*mc->GetGlobalObservables());
    newMc.SetNuisanceParameters(*mc->GetNuisanceParameters());
    newMc.SetObservables(*mc->GetObservables());

    // Add new POIs
    RooArgSet allPOI(*mc->GetParametersOfInterest());
    RooAbsArg* old_cHWtil = allPOI.find(variable_name);
    if (old_cHWtil) allPOI.remove(*old_cHWtil, true, true);
    allPOI.add(*newWs.var((std::string(variable_name) + "_combine").c_str()));
    allPOI.add(*newWs.var((std::string(variable_name) + "_"+channelname).c_str()));
    newMc.SetParametersOfInterest(allPOI);

    newWs.import(newMc);

    // Save new workspace
    TFile* outFile = TFile::Open(outputFileName, "RECREATE");
    newWs.Write();
    outFile->Close();
    inputFile->Close();

    std::cout << "New workspace written to " << outputFileName << std::endl;
}

void replace_POI_with_product() {
    for (auto& entry : files) {
        replace_cHWtil_with_product(entry.inputfilePath.c_str(), entry.outputfilePath.c_str(), entry.workspaceName.c_str(), entry.variable_name.c_str(), entry.channelname);
    }
}
